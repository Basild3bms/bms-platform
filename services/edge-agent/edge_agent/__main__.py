import logging
import time

from .config import EdgeConfig


def main() -> None:
    config = EdgeConfig.from_env()
    logging.basicConfig(level=logging.INFO)
    logging.info("Edge agent started: mode=%s writes_enabled=%s", config.mode, config.allow_device_writes)
    while True:
        time.sleep(60)


if __name__ == "__main__":
    main()
