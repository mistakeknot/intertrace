"""Tests for plugin structure."""

import os
import subprocess
import sys
from pathlib import Path

# Add interverse/ to path so _shared package is importable
_interverse = Path(__file__).resolve().parents[3]
if str(_interverse) not in sys.path:
    sys.path.insert(0, str(_interverse))

from _shared.tests.structural.test_base import StructuralTests


class TestStructure(StructuralTests):
    """Structural tests -- inherits shared base, adds plugin-specific checks."""

    def test_plugin_name(self, plugin_json):
        assert plugin_json["name"] == "intertrace"

    def test_required_files_exist(self, project_root):
        """All required root files exist (intertrace stricter set)."""
        for f in ["README.md", "CLAUDE.md", "AGENTS.md", "PHILOSOPHY.md", "LICENSE", ".gitignore"]:
            assert (project_root / f).exists(), f"Missing required file: {f}"

    def test_required_directories_exist(self, project_root):
        """All expected directories exist."""
        for d in ["skills", "agents", "lib", "scripts", "tests"]:
            assert (project_root / d).is_dir(), f"Missing directory: {d}"

    def test_lib_scripts_syntax(self, project_root):
        """All lib/*.sh files pass bash syntax check."""
        lib_dir = project_root / "lib"
        if not lib_dir.is_dir():
            return
        for sh in lib_dir.glob("*.sh"):
            result = subprocess.run(
                ["bash", "-n", str(sh)],
                capture_output=True, text=True,
            )
            assert result.returncode == 0, f"Syntax error in {sh.name}: {result.stderr}"

    def test_bump_version_executable(self, project_root):
        """scripts/bump-version.sh is executable."""
        script = project_root / "scripts" / "bump-version.sh"
        assert script.exists(), "Missing scripts/bump-version.sh"
        assert os.access(script, os.X_OK), "scripts/bump-version.sh is not executable"

    def test_agents_referenced_in_plugin_json_exist(self, project_root, plugin_json):
        """Every agent listed in plugin.json exists on disk."""
        for agent_path in plugin_json.get("agents", []):
            agent_file = project_root / agent_path.lstrip("./")
            assert agent_file.exists(), f"Agent file missing: {agent_path}"
