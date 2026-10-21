# main.py
import os
from contextlib import asynccontextmanager
from datetime import datetime
from decimal import Decimal
from typing import Dict, List, Optional

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    create_engine,
    distinct,
    func,
)
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, declarative_base, sessionmaker

# ---------------------------------------------------------------------------
# Database setup
# ---------------------------------------------------------------------------
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "mysql+pymysql://root:rootpassword@localhost:3306/insurance_db",
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()

# Claim / flag / investigation status constants
STATUS_SUBMITTED = "Submitted"
STATUS_FLAGGED = "Flagged"
STATUS_UNDER_INVESTIGATION = "Under Investigation"
STATUS_APPROVED = "Approved"
FLAG_OPEN = "Open"
PAYMENT_PENDING = "Pending"
RULE_COVERAGE_EXCEEDED = 1


# ---------------------------------------------------------------------------
# ORM models
# ---------------------------------------------------------------------------
class Customer(Base):
    __tablename__ = "Customer"
    Customer_ID = Column(Integer, primary_key=True, autoincrement=True)
    Name = Column(String(150), nullable=False)


class Policy(Base):
    __tablename__ = "Policy"
    Policy_ID = Column(Integer, primary_key=True, autoincrement=True)
    Customer_ID = Column(Integer, ForeignKey("Customer.Customer_ID"), nullable=False)
    Policy_Type = Column(String(100), nullable=False)
    Coverage_Limit = Column(Numeric(14, 2), nullable=False)


class Facility(Base):
    __tablename__ = "Facility"
    Facility_ID = Column(Integer, primary_key=True, autoincrement=True)
    Name = Column(String(200), nullable=False)


class Investigator(Base):
    __tablename__ = "Investigator"
    Investigator_ID = Column(Integer, primary_key=True, autoincrement=True)
    Name = Column(String(150), nullable=False)
    Is_Active = Column(Boolean, nullable=False, default=True)


class FraudRule(Base):
    __tablename__ = "Fraud_Rule"
    Rule_ID = Column(Integer, primary_key=True, autoincrement=True)
    Rule_Name = Column(String(150), nullable=False)
    Description = Column(Text)


class Claim(Base):
    __tablename__ = "Claim"
    Claim_ID = Column(Integer, primary_key=True, autoincrement=True)
    Customer_ID = Column(Integer, ForeignKey("Customer.Customer_ID"), nullable=False)
    Policy_ID = Column(Integer, ForeignKey("Policy.Policy_ID"), nullable=False)
    Claim_Amount = Column(Numeric(14, 2), nullable=False)
    Claim_Type = Column(String(100), nullable=False)
    Description = Column(Text)
    Status = Column(String(50), nullable=False, default=STATUS_SUBMITTED)
    Created_At = Column(DateTime, nullable=False, server_default=func.now())


class ClaimFacility(Base):
    __tablename__ = "Claim_Facility"
    Claim_ID = Column(Integer, ForeignKey("Claim.Claim_ID"), primary_key=True)
    Facility_ID = Column(Integer, ForeignKey("Facility.Facility_ID"), primary_key=True)


class FraudFlag(Base):
    __tablename__ = "Fraud_Flag"
    Flag_ID = Column(Integer, primary_key=True, autoincrement=True)
    Claim_ID = Column(Integer, ForeignKey("Claim.Claim_ID"), nullable=False)
    Rule_ID = Column(Integer, ForeignKey("Fraud_Rule.Rule_ID"), nullable=False)
    Status = Column(String(30), nullable=False, default=FLAG_OPEN)  # Open / Resolved
    Created_At = Column(DateTime, nullable=False, server_default=func.now())


class Investigation(Base):
    __tablename__ = "Investigation"
    Investigation_ID = Column(Integer, primary_key=True, autoincrement=True)
    Claim_ID = Column(Integer, ForeignKey("Claim.Claim_ID"), nullable=False)
    Investigator_ID = Column(
        Integer, ForeignKey("Investigator.Investigator_ID"), nullable=False
    )
    Status = Column(String(30), nullable=False, default="Open")
    Assigned_At = Column(DateTime, nullable=False, server_default=func.now())


class Payment(Base):
    __tablename__ = "Payment"
    Payment_ID = Column(Integer, primary_key=True, autoincrement=True)
    Claim_ID = Column(Integer, ForeignKey("Claim.Claim_ID"), nullable=False)
    Amount = Column(Numeric(14, 2), nullable=False)
    Status = Column(String(30), nullable=False, default=PAYMENT_PENDING)
    Created_At = Column(DateTime, nullable=False, server_default=func.now())


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------
class ClaimCreate(BaseModel):
    customer_id: int = Field(..., gt=0)
    policy_id: int = Field(..., gt=0)
    claim_amount: Decimal = Field(..., gt=0, max_digits=14, decimal_places=2)
    claim_type: str = Field(..., min_length=1, max_length=100)
    facility_id: int = Field(..., gt=0)
    description: Optional[str] = None


class ClaimOut(BaseModel):
    claim_id: int
    customer_id: int
    policy_id: int
    facility_id: int
    claim_amount: float
    claim_type: str
    description: Optional[str]
    status: str
    created_at: Optional[datetime]


class FlagOut(BaseModel):
    flag_id: int
    rule_id: int
    rule_name: str
    status: str


class ClaimCreateResponse(BaseModel):
    claim: ClaimOut
    flagged: bool
    flag: Optional[FlagOut] = None


class FlaggedClaimOut(BaseModel):
    claim_id: int
    customer_name: str
    policy_type: str
    claim_amount: float
    rule_id: int
    rule_violated: str


class PendingClaimOut(BaseModel):
    claim_id: int
    customer_name: str
    policy_type: str
    claim_amount: float
    claim_type: str
    rules_violated: List[str]


class InvestigatorOut(BaseModel):
    investigator_id: int
    name: str


class PendingInvestigationsResponse(BaseModel):
    pending_claims: List[PendingClaimOut]
    active_investigators: List[InvestigatorOut]


class AssignRequest(BaseModel):
    claim_id: int = Field(..., gt=0)
    investigator_id: int = Field(..., gt=0)


class AssignResponse(BaseModel):
    investigation_id: int
    claim_id: int
    investigator_id: int
    claim_status: str


class ApproveRequest(BaseModel):
    claim_id: int = Field(..., gt=0)


class ApproveResponse(BaseModel):
    claim_id: int
    claim_status: str
    payment_id: int
    payment_amount: float
    payment_status: str


class HighRiskFacility(BaseModel):
    facility_id: int
    facility_name: str
    flag_count: int


class DashboardResponse(BaseModel):
    total_claims: int
    flagged_claims: int
    total_exposure: float
    high_risk_facilities: List[HighRiskFacility]


# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(bind=engine)
    # Ensure Rule_ID = 1 (coverage limit exceeded) exists.
    with SessionLocal() as db:
        if db.get(FraudRule, RULE_COVERAGE_EXCEEDED) is None:
            db.add(
                FraudRule(
                    Rule_ID=RULE_COVERAGE_EXCEEDED,
                    Rule_Name="Claim Exceeds Coverage Limit",
                    Description="Claim amount is greater than the policy coverage limit.",
                )
            )
            db.commit()
    yield


app = FastAPI(
    title="Insurance Claim Fraud Detection API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_error_handler(_: Request, exc: SQLAlchemyError):
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Database error occurred."},
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@app.post(
    "/api/claims",
    response_model=ClaimCreateResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_claim(payload: ClaimCreate, db: Session = Depends(get_db)):
    customer = db.get(Customer, payload.customer_id)
    if customer is None:
        raise HTTPException(status_code=404, detail="Customer not found.")

    policy = db.get(Policy, payload.policy_id)
    if policy is None:
        raise HTTPException(status_code=404, detail="Policy not found.")
    if policy.Customer_ID != payload.customer_id:
        raise HTTPException(
            status_code=400, detail="Policy does not belong to the given customer."
        )

    facility = db.get(Facility, payload.facility_id)
    if facility is None:
        raise HTTPException(status_code=404, detail="Facility not found.")

    exceeds_limit = payload.claim_amount > policy.Coverage_Limit
    claim_status = STATUS_FLAGGED if exceeds_limit else STATUS_SUBMITTED

    claim = Claim(
        Customer_ID=payload.customer_id,
        Policy_ID=payload.policy_id,
        Claim_Amount=payload.claim_amount,
        Claim_Type=payload.claim_type,
        Description=payload.description,
        Status=claim_status,
    )
    db.add(claim)
    db.flush()  # populate Claim_ID

    db.add(ClaimFacility(Claim_ID=claim.Claim_ID, Facility_ID=payload.facility_id))

    flag = None
    rule = None
    if exceeds_limit:
        rule = db.get(FraudRule, RULE_COVERAGE_EXCEEDED)
        flag = FraudFlag(
            Claim_ID=claim.Claim_ID, Rule_ID=RULE_COVERAGE_EXCEEDED, Status=FLAG_OPEN
        )
        db.add(flag)
        db.flush()

    db.commit()
    db.refresh(claim)

    return ClaimCreateResponse(
        claim=ClaimOut(
            claim_id=claim.Claim_ID,
            customer_id=claim.Customer_ID,
            policy_id=claim.Policy_ID,
            facility_id=payload.facility_id,
            claim_amount=float(claim.Claim_Amount),
            claim_type=claim.Claim_Type,
            description=claim.Description,
            status=claim.Status,
            created_at=claim.Created_At,
        ),
        flagged=exceeds_limit,
        flag=FlagOut(
            flag_id=flag.Flag_ID,
            rule_id=flag.Rule_ID,
            rule_name=rule.Rule_Name if rule else "",
            status=flag.Status,
        )
        if flag
        else None,
    )


@app.get("/api/claims/flagged", response_model=List[FlaggedClaimOut])
def get_flagged_claims(db: Session = Depends(get_db)):
    rows = (
        db.query(
            Claim.Claim_ID,
            Customer.Name,
            Policy.Policy_Type,
            Claim.Claim_Amount,
            FraudRule.Rule_ID,
            FraudRule.Rule_Name,
        )
        .join(Customer, Customer.Customer_ID == Claim.Customer_ID)
        .join(Policy, Policy.Policy_ID == Claim.Policy_ID)
        .join(FraudFlag, FraudFlag.Claim_ID == Claim.Claim_ID)
        .join(FraudRule, FraudRule.Rule_ID == FraudFlag.Rule_ID)
        .filter(Claim.Status == STATUS_FLAGGED)
        .order_by(Claim.Claim_ID.desc())
        .all()
    )
    return [
        FlaggedClaimOut(
            claim_id=r[0],
            customer_name=r[1],
            policy_type=r[2],
            claim_amount=float(r[3]),
            rule_id=r[4],
            rule_violated=r[5],
        )
        for r in rows
    ]


@app.get("/api/investigations/pending", response_model=PendingInvestigationsResponse)
def get_pending_investigations(db: Session = Depends(get_db)):
    assigned_claim_ids = db.query(Investigation.Claim_ID)

    claim_rows = (
        db.query(
            Claim.Claim_ID,
            Customer.Name,
            Policy.Policy_Type,
            Claim.Claim_Amount,
            Claim.Claim_Type,
        )
        .join(Customer, Customer.Customer_ID == Claim.Customer_ID)
        .join(Policy, Policy.Policy_ID == Claim.Policy_ID)
        .filter(Claim.Status == STATUS_FLAGGED)
        .filter(~Claim.Claim_ID.in_(assigned_claim_ids))
        .order_by(Claim.Claim_ID.desc())
        .all()
    )

    claim_ids = [r[0] for r in claim_rows]
    rules_by_claim: Dict[int, List[str]] = {cid: [] for cid in claim_ids}
    if claim_ids:
        rule_rows = (
            db.query(FraudFlag.Claim_ID, FraudRule.Rule_Name)
            .join(FraudRule, FraudRule.Rule_ID == FraudFlag.Rule_ID)
            .filter(FraudFlag.Claim_ID.in_(claim_ids))
            .all()
        )
        for cid, rule_name in rule_rows:
            rules_by_claim[cid].append(rule_name)

    investigators = (
        db.query(Investigator)
        .filter(Investigator.Is_Active.is_(True))
        .order_by(Investigator.Name)
        .all()
    )

    return PendingInvestigationsResponse(
        pending_claims=[
            PendingClaimOut(
                claim_id=r[0],
                customer_name=r[1],
                policy_type=r[2],
                claim_amount=float(r[3]),
                claim_type=r[4],
                rules_violated=rules_by_claim.get(r[0], []),
            )
            for r in claim_rows
        ],
        active_investigators=[
            InvestigatorOut(investigator_id=i.Investigator_ID, name=i.Name)
            for i in investigators
        ],
    )


@app.post(
    "/api/investigations/assign",
    response_model=AssignResponse,
    status_code=status.HTTP_201_CREATED,
)
def assign_investigator(payload: AssignRequest, db: Session = Depends(get_db)):
    claim = db.get(Claim, payload.claim_id)
    if claim is None:
        raise HTTPException(status_code=404, detail="Claim not found.")

    investigator = db.get(Investigator, payload.investigator_id)
    if investigator is None:
        raise HTTPException(status_code=404, detail="Investigator not found.")
    if not investigator.Is_Active:
        raise HTTPException(status_code=400, detail="Investigator is not active.")

    existing = (
        db.query(Investigation).filter(Investigation.Claim_ID == claim.Claim_ID).first()
    )
    if existing is not None:
        raise HTTPException(
            status_code=409, detail="Claim already has an assigned investigator."
        )
    if claim.Status != STATUS_FLAGGED:
        raise HTTPException(
            status_code=409,
            detail=f"Only claims with status '{STATUS_FLAGGED}' can be assigned.",
        )

    investigation = Investigation(
        Claim_ID=claim.Claim_ID, Investigator_ID=investigator.Investigator_ID
    )
    db.add(investigation)
    claim.Status = STATUS_UNDER_INVESTIGATION
    db.flush()
    investigation_id = investigation.Investigation_ID
    db.commit()

    return AssignResponse(
        investigation_id=investigation_id,
        claim_id=claim.Claim_ID,
        investigator_id=investigator.Investigator_ID,
        claim_status=STATUS_UNDER_INVESTIGATION,
    )


@app.post("/api/claims/approve", response_model=ApproveResponse)
def approve_claim(payload: ApproveRequest, db: Session = Depends(get_db)):
    claim = db.get(Claim, payload.claim_id)
    if claim is None:
        raise HTTPException(status_code=404, detail="Claim not found.")
    if claim.Status == STATUS_APPROVED:
        raise HTTPException(status_code=409, detail="Claim is already approved.")

    open_flags = (
        db.query(func.count(FraudFlag.Flag_ID))
        .filter(FraudFlag.Claim_ID == claim.Claim_ID, FraudFlag.Status == FLAG_OPEN)
        .scalar()
    )
    if open_flags and open_flags > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot approve claim: {open_flags} unresolved fraud flag(s).",
        )

    claim.Status = STATUS_APPROVED
    payment = Payment(
        Claim_ID=claim.Claim_ID, Amount=claim.Claim_Amount, Status=PAYMENT_PENDING
    )
    db.add(payment)
    db.flush()
    payment_id = payment.Payment_ID
    db.commit()

    return ApproveResponse(
        claim_id=claim.Claim_ID,
        claim_status=STATUS_APPROVED,
        payment_id=payment_id,
        payment_amount=float(claim.Claim_Amount),
        payment_status=PAYMENT_PENDING,
    )


@app.get("/api/analytics/dashboard", response_model=DashboardResponse)
def get_dashboard(db: Session = Depends(get_db)):
    total_claims = db.query(func.count(Claim.Claim_ID)).scalar() or 0

    # "Flagged" = any claim that has at least one fraud flag, so the figures stay
    # stable after a claim moves on to 'Under Investigation'.
    flagged_claim_ids = db.query(distinct(FraudFlag.Claim_ID))
    flagged_claims = (
        db.query(func.count(Claim.Claim_ID))
        .filter(Claim.Claim_ID.in_(flagged_claim_ids))
        .scalar()
        or 0
    )
    total_exposure = (
        db.query(func.coalesce(func.sum(Claim.Claim_Amount), 0))
        .filter(Claim.Claim_ID.in_(flagged_claim_ids))
        .scalar()
    )

    facility_rows = (
        db.query(
            Facility.Facility_ID,
            Facility.Name,
            func.count(FraudFlag.Flag_ID).label("flag_count"),
        )
        .join(ClaimFacility, ClaimFacility.Facility_ID == Facility.Facility_ID)
        .join(FraudFlag, FraudFlag.Claim_ID == ClaimFacility.Claim_ID)
        .group_by(Facility.Facility_ID, Facility.Name)
        .order_by(func.count(FraudFlag.Flag_ID).desc(), Facility.Facility_ID)
        .limit(3)
        .all()
    )

    return DashboardResponse(
        total_claims=int(total_claims),
        flagged_claims=int(flagged_claims),
        total_exposure=float(total_exposure or 0),
        high_risk_facilities=[
            HighRiskFacility(facility_id=r[0], facility_name=r[1], flag_count=int(r[2]))
            for r in facility_rows
        ],
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)