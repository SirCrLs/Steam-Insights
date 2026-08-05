import json
import os
import logging

# Database utility functions for the Steam-Insights.

logger = logging.getLogger(__name__)

CHECKPOINT_PATH = os.path.join("..", "data", "steamspy_checkpoint.json")

def get_last_completed_page() -> int:
    """
    Returns the last SteamSpy page successfully inserted into the database.
    Returns -1 if no checkpoint exists yet.
    """
    if not os.path.exists(CHECKPOINT_PATH):
        return -1
    with open(CHECKPOINT_PATH, "r", encoding="utf-8") as f:
        checkpoint = json.load(f)
    return checkpoint.get("last_page", -1)

def save_checkpoint(page: int) -> None:
    """
    Updates the checkpoint file to record the last page successfully 
    inserted into the database.
    """
    with open(CHECKPOINT_PATH, "w", encoding="utf-8") as f:
        json.dump({"last_page": page}, f)
    logger.info(f"Checkpoint updated: last completed page = {page}")
