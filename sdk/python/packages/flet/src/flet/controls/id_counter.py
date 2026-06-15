import itertools
import threading
from typing import Optional


class IdCounter:
    """
    Thread-safe incremental id generator used for runtime control identifiers.
    """

    def __init__(
        self, start: int = 1, step: int = 1, lock: Optional[threading.Lock] = None
    ):
        self._counter = itertools.count(start, step)
        self._lock = lock or threading.Lock()

    def next(self) -> int:
        """
        Return the next id value from the counter.
        """
        with self._lock:
            return next(self._counter)

    def __call__(self) -> int:  # for dataclass default_factory
        return self.next()


ControlId = IdCounter(start=3)
