"""Registry of the local model profiles; the llama.cpp launchers are retired."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location("gen_launchers", ROOT / "gen.py")
gen = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gen)
NINFER = Path("/home/alex/Applications/ninfer-all")


class LauncherTests(unittest.TestCase):
    def test_registry_maps_both_profiles_to_ninfer(self):
        self.assertEqual(set(gen.LAUNCHERS), {"image", "video", "qw", "gm"})
        self.assertEqual(gen.LAUNCHERS["qw"], NINFER / "run-bonsai2-ninfer.fish")
        self.assertEqual(gen.LAUNCHERS["gm"], NINFER / "run-gemma4-ninfer.fish")
        # Every text profile is an original external launcher: there is no launchers/
        # file to reconstruct and no llama.cpp profile left to keep in sync.
        self.assertEqual(set(gen.TEXT_PROFILES), set(gen.ORIGINAL))

    def test_launchers_dir_is_gone(self):
        self.assertFalse((ROOT / "launchers").exists())


if __name__ == "__main__":
    unittest.main()
