"""Tests for base_ref.resolve (Decision 50), against throwaway git repositories."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import base_ref  # noqa: E402


def git(repo, *args):
    subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True)


def commit(repo, name):
    (Path(repo) / f"{name}.txt").write_text(name, encoding="utf-8")
    git(repo, "add", ".")
    git(repo, "commit", "-q", "-m", name)


def publish(repo, branch):
    """Records the branch's tip as if pushed: refs/remotes/origin/<branch>."""
    git(repo, "update-ref", f"refs/remotes/origin/{branch}", branch)


class StackedRepo(unittest.TestCase):
    """main <- feature/a <- feature/b, each published, with HEAD on feature/b."""

    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.repo = self._dir.name
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.email", "test@example.com")
        git(self.repo, "config", "user.name", "Test")
        commit(self.repo, "root")
        publish(self.repo, "main")
        git(self.repo, "checkout", "-q", "-b", "feature/a")
        commit(self.repo, "a")
        publish(self.repo, "feature/a")
        git(self.repo, "checkout", "-q", "-b", "feature/b")
        commit(self.repo, "b")
        publish(self.repo, "feature/b")

    def tearDown(self):
        self._dir.cleanup()

    def test_a_stacked_branch_compares_against_the_branch_below_it(self):
        self.assertEqual(base_ref.resolve(["check"], env={}, cwd=self.repo), "origin/feature/a")

    def test_a_branch_off_main_compares_against_main(self):
        git(self.repo, "checkout", "-q", "feature/a")

        self.assertEqual(base_ref.resolve(["check"], env={}, cwd=self.repo), "origin/main")

    def test_an_explicit_argument_wins(self):
        self.assertEqual(
            base_ref.resolve(["check", "origin/main"], env={"BASE_REF": "x"}, cwd=self.repo),
            "origin/main",
        )

    def test_the_environment_wins_over_detection(self):
        env = {"BASE_REF": "origin/main"}

        self.assertEqual(base_ref.resolve(["check"], env=env, cwd=self.repo), "origin/main")

    def test_with_no_remote_branches_it_falls_back_to_main(self):
        for branch in ("main", "feature/a", "feature/b"):
            git(self.repo, "update-ref", "-d", f"refs/remotes/origin/{branch}")

        self.assertEqual(base_ref.resolve(["check"], env={}, cwd=self.repo), "origin/main")


if __name__ == "__main__":
    unittest.main()
