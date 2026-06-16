# Exporta los modelos para que database.init_db() los descubra automáticamente
from .user import User
from .enrollment import Enrollment
from .credential import IssuedCredential
from .activity import ActivityLog

__all__ = ["User", "Enrollment", "IssuedCredential", "ActivityLog"]
