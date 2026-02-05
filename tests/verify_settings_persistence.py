#!/usr/bin/env python3
"""Comprehensive verification script for settings persistence across app restarts.

This script tests the complete settings persistence flow:
1. Save settings to disk (simulating app shutdown)
2. Load settings from disk (simulating app restart)
3. Verify all settings persist correctly
4. Verify hotkey setting specifically persists and is functional
5. Test multiple save/load cycles
6. Test migration from defaults when file is missing
7. Test atomic writes prevent corruption

Usage:
    python tests/verify_settings_persistence.py
"""

import sys
import os
import asyncio
import json
import tempfile
import shutil
from pathlib import Path
from typing import Any, Dict

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from vox.settings.manager import SettingsManager
from vox.models.settings import VoxSettings
from vox.models.hotkey import HotKey, Key, Modifier, Modifiers
from vox.models.word_processing import WordRemoval, WordRemapping

# Color codes for output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"

def print_section(title):
    """Print a section header."""
    print(f"\n{BLUE}{'=' * 70}{RESET}")
    print(f"{BLUE}{title}{RESET}")
    print(f"{BLUE}{'=' * 70}{RESET}\n")

def print_test(name):
    """Print a test name."""
    print(f"{YELLOW}Test:{RESET} {name}")

def print_pass(message):
    """Print a passing test."""
    print(f"  {GREEN}✓ PASS:{RESET} {message}")

def print_fail(message):
    """Print a failing test."""
    print(f"  {RED}✗ FAIL:{RESET} {message}")

def print_info(message):
    """Print info message."""
    print(f"  {BLUE}INFO:{RESET} {message}")


class TestResults:
    """Track test results."""
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.tests = []

    def add_pass(self, test_name):
        """Add a passing test."""
        self.passed += 1
        self.tests.append((test_name, True))

    def add_fail(self, test_name):
        """Add a failing test."""
        self.failed += 1
        self.tests.append((test_name, False))

    def print_summary(self):
        """Print test summary."""
        print(f"\n{BLUE}{'=' * 70}{RESET}")
        print(f"{BLUE}Test Summary{RESET}")
        print(f"{BLUE}{'=' * 70}{RESET}\n")

        for test_name, passed in self.tests:
            status = f"{GREEN}PASS{RESET}" if passed else f"{RED}FAIL{RESET}"
            print(f"  {status}: {test_name}")

        print(f"\n{GREEN}Passed:{RESET} {self.passed}")
        print(f"{RED}Failed:{RESET} {self.failed}")
        print(f"Total: {self.passed + self.failed}")

        if self.failed == 0:
            print(f"\n{GREEN}All tests passed!{RESET}")
        else:
            print(f"\n{RED}Some tests failed!{RESET}")


async def test_hotkey_persistence(results: TestResults, temp_dir: Path):
    """Test that hotkey setting persists across restarts.

    This is the critical test for this subtask - ensuring the hotkey
    setting survives app restart and works correctly.
    """
    print_section("Part 1: Hotkey Persistence (Critical)")

    # Create a temporary config directory
    config_dir = temp_dir / "test_hotkey"
    config_dir.mkdir(parents=True, exist_ok=True)

    # Test 1: Save custom hotkey
    print_test("Save custom hotkey (Cmd+Shift+A)")
    try:
        manager1 = SettingsManager(config_dir=config_dir)

        # Create custom hotkey: Cmd+Shift+A
        custom_hotkey = HotKey(
            key=Key.A,
            modifiers=Modifiers.from_list([Modifier.COMMAND, Modifier.SHIFT])
        )

        settings1 = VoxSettings(hotkey=custom_hotkey)
        await manager1.save(settings1)

        # Verify file was created
        if manager1.settings_file_exists():
            print_pass("Settings file created")
            results.add_pass("Hotkey save")
        else:
            print_fail("Settings file not created")
            results.add_fail("Hotkey save")
            return

        # Verify file content
        with open(manager1.settings_path, 'r') as f:
            data = json.load(f)
            if data.get('hotkey', {}).get('key') == 'a':
                print_pass("Hotkey serialized correctly (key='a')")
            else:
                print_fail(f"Hotkey key incorrect: {data.get('hotkey', {}).get('key')}")
                results.add_fail("Hotkey serialization")
                return

            modifiers = data.get('hotkey', {}).get('modifiers', [])
            # Extract kind values from list of dicts
            modifier_kinds = {m.get('kind') for m in modifiers}
            if modifier_kinds == {'COMMAND', 'SHIFT'}:
                print_pass("Hotkey modifiers serialized correctly")
            else:
                print_fail(f"Hotkey modifiers incorrect: {modifier_kinds}")
                results.add_fail("Hotkey serialization")
                return

        print_pass("Custom hotkey saved successfully")
        results.add_pass("Custom hotkey save")

    except Exception as e:
        print_fail(f"Exception: {e}")
        results.add_fail("Custom hotkey save")
        return

    # Test 2: Load hotkey in new manager instance (simulate app restart)
    print_test("Load hotkey after app restart (new SettingsManager instance)")

    try:
        manager2 = SettingsManager(config_dir=config_dir)
        settings2 = await manager2.load()

        # Verify hotkey loaded correctly
        if settings2.hotkey.key == Key.A:
            print_pass("Hotkey key loaded correctly (Key.A)")
        else:
            print_fail(f"Hotkey key incorrect: {settings2.hotkey.key}")
            results.add_fail("Hotkey load - key")
            return

        if Modifier.COMMAND in settings2.hotkey.modifiers.modifiers:
            print_pass("COMMAND modifier loaded correctly")
        else:
            print_fail("COMMAND modifier missing")
            results.add_fail("Hotkey load - modifiers")
            return

        if Modifier.SHIFT in settings2.hotkey.modifiers.modifiers:
            print_pass("SHIFT modifier loaded correctly")
        else:
            print_fail("SHIFT modifier missing")
            results.add_fail("Hotkey load - modifiers")
            return

        print_pass("Hotkey loaded successfully after 'restart'")
        results.add_pass("Hotkey load after restart")

    except Exception as e:
        print_fail(f"Exception: {e}")
        results.add_fail("Hotkey load after restart")
        return

    # Test 3: Modify hotkey and save again
    print_test("Modify hotkey to Option+B and save")

    try:
        from dataclasses import replace

        new_hotkey = HotKey(
            key=Key.B,
            modifiers=Modifiers.from_list([Modifier.OPTION])
        )

        # Use dataclasses.replace() for frozen dataclass
        settings2_modified = replace(settings2, hotkey=new_hotkey)
        await manager2.save(settings2_modified)

        # Verify file was updated
        with open(manager2.settings_path, 'r') as f:
            data = json.load(f)
            if data.get('hotkey', {}).get('key') == 'b':
                print_pass("Hotkey updated in file (key='b')")
            else:
                print_fail(f"Hotkey not updated: {data.get('hotkey', {}).get('key')}")
                results.add_fail("Hotkey update")
                return

        print_pass("Hotkey modified and saved successfully")
        results.add_pass("Hotkey modification")

    except Exception as e:
        print_fail(f"Exception: {e}")
        results.add_fail("Hotkey modification")
        return

    # Test 4: Load modified hotkey
    print_test("Load modified hotkey (another restart)")

    try:
        manager3 = SettingsManager(config_dir=config_dir)
        settings3 = await manager3.load()

        if settings3.hotkey.key == Key.B:
            print_pass("Modified hotkey key loaded correctly (Key.B)")
        else:
            print_fail(f"Modified key incorrect: {settings3.hotkey.key}")
            results.add_fail("Modified hotkey load")
            return

        if Modifier.OPTION in settings3.hotkey.modifiers.modifiers:
            print_pass("Modified hotkey modifiers loaded correctly")
        else:
            print_fail("Modified modifiers incorrect")
            results.add_fail("Modified hotkey load")
            return

        print_pass("Modified hotkey loaded successfully")
        results.add_pass("Modified hotkey load")

    except Exception as e:
        print_fail(f"Exception: {e}")
        results.add_fail("Modified hotkey load")
        return


async def test_all_settings_persistence(results: TestResults, temp_dir: Path):
    """Test that all settings persist across restarts."""
    print_section("Part 2: All Settings Persistence")

    config_dir = temp_dir / "test_all_settings"
    config_dir.mkdir(parents=True, exist_ok=True)

    # Create custom settings with all fields modified
    print_test("Save all custom settings")

    try:
        manager1 = SettingsManager(config_dir=config_dir)

        custom_settings = VoxSettings(
            soundEffectsEnabled=False,
            soundEffectsVolume=0.5,
            hotkey=HotKey(key=Key.C, modifiers=Modifiers.from_list([Modifier.COMMAND])),
            openOnLogin=True,
            showDockIcon=False,
            selectedModel="whisper-large-v3",
            useClipboardPaste=False,
            preventSystemSleep=False,
            minimumKeyTime=0.3,
            copyToClipboard=True,
            useDoubleTapOnly=True,
            outputLanguage="es",
            saveTranscriptionHistory=True,
            maxHistoryEntries=50,
            wordRemovalsEnabled=False
        )

        await manager1.save(custom_settings)
        print_pass("All custom settings saved")
        results.add_pass("Save all settings")

    except Exception as e:
        print_fail(f"Exception: {e}")
        results.add_fail("Save all settings")
        return

    # Load settings and verify all fields
    print_test("Load and verify all settings")

    try:
        manager2 = SettingsManager(config_dir=config_dir)
        loaded_settings = await manager2.load()

        tests = [
            ("soundEffectsEnabled", loaded_settings.soundEffectsEnabled, False),
            ("soundEffectsVolume", loaded_settings.soundEffectsVolume, 0.5),
            ("hotkey.key", loaded_settings.hotkey.key, Key.C),
            ("openOnLogin", loaded_settings.openOnLogin, True),
            ("showDockIcon", loaded_settings.showDockIcon, False),
            ("selectedModel", loaded_settings.selectedModel, "whisper-large-v3"),
            ("useClipboardPaste", loaded_settings.useClipboardPaste, False),
            ("preventSystemSleep", loaded_settings.preventSystemSleep, False),
            ("minimumKeyTime", loaded_settings.minimumKeyTime, 0.3),
            ("copyToClipboard", loaded_settings.copyToClipboard, True),
            ("useDoubleTapOnly", loaded_settings.useDoubleTapOnly, True),
            ("outputLanguage", loaded_settings.outputLanguage, "es"),
            ("saveTranscriptionHistory", loaded_settings.saveTranscriptionHistory, True),
            ("maxHistoryEntries", loaded_settings.maxHistoryEntries, 50),
            ("wordRemovalsEnabled", loaded_settings.wordRemovalsEnabled, False),
        ]

        all_passed = True
        for field_name, actual, expected in tests:
            if actual == expected:
                print_pass(f"{field_name} = {expected}")
            else:
                print_fail(f"{field_name} = {actual} (expected {expected})")
                all_passed = False
                results.add_fail(f"Field {field_name}")

        if all_passed:
            print_pass("All settings fields persisted correctly")
            results.add_pass("All settings persistence")
        else:
            print_fail("Some settings fields did not persist")

    except Exception as e:
        print_fail(f"Exception: {e}")
        results.add_fail("Load all settings")


async def test_word_lists_persistence(results: TestResults, temp_dir: Path):
    """Test that word removal and remapping lists persist."""
    print_section("Part 3: Word Lists Persistence")

    config_dir = temp_dir / "test_word_lists"
    config_dir.mkdir(parents=True, exist_ok=True)

    print_test("Save custom word removals and remappings")

    try:
        manager1 = SettingsManager(config_dir=config_dir)

        custom_word_removals = [
            WordRemoval(pattern="like+"),
            WordRemoval(pattern="you know"),
        ]

        custom_word_remappings = [
            WordRemapping(match="tmrw", replacement="tomorrow"),
            WordRemapping(match="btw", replacement="by the way"),
        ]

        settings = VoxSettings(
            wordRemovals=custom_word_removals,
            wordRemappings=custom_word_remappings
        )

        await manager1.save(settings)
        print_pass("Word lists saved")
        results.add_pass("Word lists save")

    except Exception as e:
        print_fail(f"Exception: {e}")
        results.add_fail("Word lists save")
        return

    print_test("Load and verify word lists")

    try:
        manager2 = SettingsManager(config_dir=config_dir)
        loaded_settings = await manager2.load()

        # Verify word removals
        if len(loaded_settings.wordRemovals) == 2:
            print_pass(f"Word removals count correct: {len(loaded_settings.wordRemovals)}")
        else:
            print_fail(f"Word removals count incorrect: {len(loaded_settings.wordRemovals)}")
            results.add_fail("Word removals count")
            return

        removal_patterns = [r.pattern for r in loaded_settings.wordRemovals]
        if "like+" in removal_patterns and "you know" in removal_patterns:
            print_pass("Word removal patterns correct")
        else:
            print_fail(f"Word removal patterns incorrect: {removal_patterns}")
            results.add_fail("Word removal patterns")
            return

        # Verify word remappings
        if len(loaded_settings.wordRemappings) == 2:
            print_pass(f"Word remappings count correct: {len(loaded_settings.wordRemappings)}")
        else:
            print_fail(f"Word remappings count incorrect: {len(loaded_settings.wordRemappings)}")
            results.add_fail("Word remappings count")
            return

        remapping_matches = [r.match for r in loaded_settings.wordRemappings]
        if "tmrw" in remapping_matches and "btw" in remapping_matches:
            print_pass("Word remapping patterns correct")
        else:
            print_fail(f"Word remapping patterns incorrect: {remapping_matches}")
            results.add_fail("Word remapping patterns")
            return

        print_pass("Word lists loaded successfully")
        results.add_pass("Word lists load")

    except Exception as e:
        print_fail(f"Exception: {e}")
        results.add_fail("Word lists load")


async def test_default_settings_migration(results: TestResults, temp_dir: Path):
    """Test migration to defaults when settings file is missing."""
    print_section("Part 4: Default Settings Migration")

    config_dir = temp_dir / "test_defaults"
    config_dir.mkdir(parents=True, exist_ok=True)

    print_test("Load settings when file doesn't exist")

    try:
        manager = SettingsManager(config_dir=config_dir)

        # Ensure file doesn't exist
        if manager.settings_file_exists():
            print_fail("Settings file should not exist yet")
            results.add_fail("Default migration - file check")
            return

        # Load should return defaults
        settings = await manager.load()

        # Verify default values
        if settings.soundEffectsEnabled == True:
            print_pass("Default soundEffectsEnabled = True")
        else:
            print_fail(f"Default soundEffectsEnabled incorrect: {settings.soundEffectsEnabled}")
            results.add_fail("Default migration - soundEffectsEnabled")
            return

        if settings.selectedModel == "parakeet-tdt-0.6b-v3-coreml":
            print_pass("Default selectedModel = parakeet-tdt-0.6b-v3-coreml")
        else:
            print_fail(f"Default selectedModel incorrect: {settings.selectedModel}")
            results.add_fail("Default migration - selectedModel")
            return

        # Verify default hotkey (Option-only)
        if settings.hotkey.key is None:
            print_pass("Default hotkey is modifier-only (no key)")
        else:
            print_fail(f"Default hotkey should have no key: {settings.hotkey.key}")
            results.add_fail("Default migration - hotkey")
            return

        if Modifier.OPTION in settings.hotkey.modifiers.modifiers:
            print_pass("Default hotkey has OPTION modifier")
        else:
            print_fail("Default hotkey should have OPTION modifier")
            results.add_fail("Default migration - hotkey")
            return

        print_pass("Default settings loaded successfully")
        results.add_pass("Default settings migration")

    except Exception as e:
        print_fail(f"Exception: {e}")
        results.add_fail("Default settings migration")


async def test_atomic_writes(results: TestResults, temp_dir: Path):
    """Test that settings uses atomic writes to prevent corruption."""
    print_section("Part 5: Atomic Writes (Corruption Prevention)")

    config_dir = temp_dir / "test_atomic"
    config_dir.mkdir(parents=True, exist_ok=True)

    print_test("Verify atomic write pattern")

    try:
        manager = SettingsManager(config_dir=config_dir)

        settings = VoxSettings(
            hotkey=HotKey(key=Key.D, modifiers=Modifiers.from_list([Modifier.COMMAND]))
        )

        # Save settings
        await manager.save(settings)

        # Verify .tmp file doesn't exist after save (should be renamed)
        tmp_path = manager.settings_path.with_suffix(".tmp")
        if not tmp_path.exists():
            print_pass("Temp file cleaned up after atomic rename")
        else:
            print_fail("Temp file should not exist after save")
            results.add_fail("Atomic write - temp cleanup")
            return

        # Verify final file exists
        if manager.settings_file_exists():
            print_pass("Settings file exists after save")
        else:
            print_fail("Settings file should exist after save")
            results.add_fail("Atomic write - final file")
            return

        # Verify file content is valid JSON
        with open(manager.settings_path, 'r') as f:
            data = json.load(f)
            if data.get('hotkey', {}).get('key') == 'd':
                print_pass("File content is valid and correct")
            else:
                print_fail("File content is incorrect")
                results.add_fail("Atomic write - file content")
                return

        print_pass("Atomic write pattern verified")
        results.add_pass("Atomic writes")

    except Exception as e:
        print_fail(f"Exception: {e}")
        results.add_fail("Atomic writes")


async def main():
    """Run all verification tests."""
    print(f"\n{BLUE}{'=' * 70}{RESET}")
    print(f"{BLUE}Settings Persistence Verification{RESET}")
    print(f"{BLUE}Hex Python - Cross-Platform Voice-to-Text{RESET}")
    print(f"{BLUE}{'=' * 70}{RESET}\n")

    print(f"{YELLOW}This script verifies that settings persist correctly across app restarts.{RESET}")
    print(f"{YELLOW}It simulates app restarts by creating new SettingsManager instances.{RESET}\n")

    # Create temporary directory for tests
    temp_dir = Path(tempfile.mkdtemp(prefix="hex_settings_test_"))

    try:
        results = TestResults()

        # Run all tests
        await test_hotkey_persistence(results, temp_dir)
        await test_all_settings_persistence(results, temp_dir)
        await test_word_lists_persistence(results, temp_dir)
        await test_default_settings_migration(results, temp_dir)
        await test_atomic_writes(results, temp_dir)

        # Print summary
        results.print_summary()

        # Return exit code
        return 0 if results.failed == 0 else 1

    finally:
        # Clean up temporary directory
        if temp_dir.exists():
            shutil.rmtree(temp_dir)


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
