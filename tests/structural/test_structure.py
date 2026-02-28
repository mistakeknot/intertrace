"""Tests for intertrace plugin structure."""

import json
import subprocess
from pathlib import Path


def test_plugin_json_valid(project_root):
    """plugin.json is valid JSON with required fields."""
    path = project_root / ".claude-plugin" / "plugin.json"
    assert path.exists(), "Missing .claude-plugin/plugin.json"
    data = json.loads(path.read_text())
    assert data["name"] == "intertrace"
    assert "version" in data
    assert "description" in data


def test_required_files_exist(project_root):
    """All required root files exist."""
    for f in ["README.md", "CLAUDE.md", "AGENTS.md", "PHILOSOPHY.md", "LICENSE", ".gitignore"]:
        assert (project_root / f).exists(), f"Missing required file: {f}"


def test_required_directories_exist(project_root):
    """All expected directories exist."""
    for d in ["skills", "agents", "lib", "scripts", "tests"]:
        assert (project_root / d).is_dir(), f"Missing directory: {d}"


def test_lib_scripts_syntax(project_root):
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


def test_bump_version_executable(project_root):
    """scripts/bump-version.sh is executable."""
    script = project_root / "scripts" / "bump-version.sh"
    assert script.exists(), "Missing scripts/bump-version.sh"
    import os
    assert os.access(script, os.X_OK), "scripts/bump-version.sh is not executable"


def test_skills_referenced_in_plugin_json_exist(project_root, plugin_json):
    """Every skill listed in plugin.json exists on disk."""
    for skill_path in plugin_json.get("skills", []):
        skill_dir = project_root / skill_path.lstrip("./")
        assert skill_dir.is_dir(), f"Skill directory missing: {skill_path}"
        assert (skill_dir / "SKILL.md").exists(), f"Missing SKILL.md in {skill_path}"


def test_agents_referenced_in_plugin_json_exist(project_root, plugin_json):
    """Every agent listed in plugin.json exists on disk."""
    for agent_path in plugin_json.get("agents", []):
        agent_file = project_root / agent_path.lstrip("./")
        assert agent_file.exists(), f"Agent file missing: {agent_path}"
