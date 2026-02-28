"""Tests for intertrace skill definitions."""

from pathlib import Path

from helpers import parse_frontmatter


def test_intertrace_skill_has_frontmatter(project_root):
    """intertrace skill has valid YAML frontmatter with description."""
    skill = project_root / "skills" / "intertrace" / "SKILL.md"
    assert skill.exists(), "Missing skills/intertrace/SKILL.md"
    fm, _ = parse_frontmatter(skill)
    assert fm is not None, "SKILL.md missing YAML frontmatter"
    assert "description" in fm, "SKILL.md frontmatter missing 'description'"


def test_fd_integration_agent_has_frontmatter(project_root):
    """fd-integration agent has valid YAML frontmatter."""
    agent = project_root / "agents" / "review" / "fd-integration.md"
    assert agent.exists(), "Missing agents/review/fd-integration.md"
    fm, _ = parse_frontmatter(agent)
    assert fm is not None, "fd-integration.md missing YAML frontmatter"
    assert "name" in fm, "Agent frontmatter missing 'name'"
    assert "description" in fm, "Agent frontmatter missing 'description'"
    assert "model" in fm, "Agent frontmatter missing 'model'"
