import os
import unittest
from unittest.mock import patch

from edge_agent.config import EdgeConfig


class EdgeConfigTest(unittest.TestCase):
    def test_default_blocks_physical_writes(self):
        with patch.dict(os.environ, {}, clear=True):
            config = EdgeConfig.from_env()
        self.assertEqual(config.mode, "simulation")
        with self.assertRaises(PermissionError):
            config.assert_write_allowed()

    def test_simulation_blocks_writes_even_if_flag_is_set(self):
        with patch.dict(os.environ, {"BMS_ALLOW_DEVICE_WRITES": "true"}, clear=True):
            config = EdgeConfig.from_env()
        with self.assertRaises(PermissionError):
            config.assert_write_allowed()
