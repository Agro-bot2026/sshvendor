from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.orm import declarative_base
from datetime import datetime

Base = declarative_base()

class Licencia(Base):
    __tablename__ = "licencias"
    id = Column(Integer, primary_key=True, index=True)
    token = Column(String, unique=True, index=True, nullable=False)
    cliente = Column(String, default="")
    ip_bound = Column(String, default=None, nullable=True)
    ip_registered = Column(String, default=None, nullable=True)
    ip_changes_used = Column(Integer, default=0)
    status = Column(String, default="active")
    bot_version = Column(String, default="")
    last_seen = Column(DateTime, default=None, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
