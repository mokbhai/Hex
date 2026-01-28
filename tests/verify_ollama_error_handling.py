#!/usr/bin/env python3
"""Comprehensive verification script for Ollama server error handling.

This script tests the complete Ollama server error handling flow:
1. TranscriptionClient detects Ollama server is not running
2. Helpful error messages are shown with clear troubleshooting steps
3. transcribe() method properly handles connection errors
4. Error messages include server URL, installation links, and command examples

Usage:
    python tests/verify_ollama_error_handling.py
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

import asyncio
from pathlib import Path

# Try to import, but provide helpful error if dependencies missing
try:
    from vox.clients.transcription import (
        TranscriptionClient,
        OllamaConnectionError,
        TranscriptionError
    )
    DEPENDENCIES_AVAILABLE = True
except ImportError as e:
    DEPENDENCIES_AVAILABLE = False
    IMPORT_ERROR = str(e)

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
    """Print an info message."""
    print(f"  {BLUE}INFO:{RESET} {message}")

async def verify_server_check_raises_error():
    """Verify _check_ollama_server raises OllamaConnectionError when server not running."""
    print_section("PART 1: Server Check Error Detection")

    tests_passed = 0
    tests_failed = 0

    # Test 1: _check_ollama_server raises OllamaConnectionError
    print_test("check_ollama_server() raises OllamaConnectionError when server not running")
    try:
        client = TranscriptionClient(model="whisper")

        # Use a non-existent server to ensure connection fails
        client.ollama_host = "http://localhost:9999"  # Wrong port

        try:
            await client._check_ollama_server()
            print_fail("Expected OllamaConnectionError but no exception was raised")
            tests_failed += 1
        except OllamaConnectionError as e:
            print_pass(f"OllamaConnectionError raised as expected: {type(e).__name__}")
            tests_passed += 1
        except Exception as e:
            print_fail(f"Wrong exception type: {type(e).__name__}")
            tests_failed += 1

    except Exception as e:
        print_fail(f"Test setup failed: {e}")
        tests_failed += 1

    # Test 2: OllamaConnectionError has helpful message
    print_test("OllamaConnectionError contains helpful error message")
    try:
        client = TranscriptionClient(model="whisper")
        client.ollama_host = "http://localhost:9999"

        try:
            await client._check_ollama_server()
            print_fail("Expected OllamaConnectionError but no exception was raised")
            tests_failed += 1
        except OllamaConnectionError as e:
            error_msg = str(e)

            # Check for required elements
            required_elements = [
                ("Server URL", "http://"),
                ("Solutions section", "Possible solutions"),
                ("Command example", "ollama serve"),
                ("Installation link", "ollama.ai")
            ]

            all_present = True
            for name, element in required_elements:
                if element in error_msg:
                    print_pass(f"Contains {name}")
                else:
                    print_fail(f"Missing {name}")
                    all_present = False

            if all_present:
                print_pass("Error message contains all required helpful elements")
                tests_passed += 1
            else:
                print_fail("Error message missing some required elements")
                tests_failed += 1

    except Exception as e:
        print_fail(f"Test setup failed: {e}")
        tests_failed += 1

    print(f"\n{GREEN}Passed:{RESET} {tests_passed}/{tests_passed + tests_failed}")
    return tests_passed, tests_failed

async def verify_error_message_quality():
    """Verify error messages are comprehensive and actionable."""
    print_section("PART 2: Error Message Quality")

    tests_passed = 0
    tests_failed = 0

    print_test("Error message includes numbered troubleshooting steps")
    try:
        client = TranscriptionClient(model="whisper")
        client.ollama_host = "http://localhost:9999"

        try:
            await client._check_ollama_server()
            print_fail("Expected OllamaConnectionError but no exception was raised")
            tests_failed += 1
        except OllamaConnectionError as e:
            error_msg = str(e)

            # Check for numbered steps
            has_numbered_steps = any(
                f"{i}." in error_msg or f"{i} " in error_msg
                for i in range(1, 10)
            )

            if has_numbered_steps:
                print_pass("Error message includes numbered steps")
                tests_passed += 1
            else:
                print_fail("Error message missing numbered steps")
                tests_failed += 1

    except Exception as e:
        print_fail(f"Test setup failed: {e}")
        tests_failed += 1

    print_test("Error message includes server URL")
    try:
        client = TranscriptionClient(model="whisper")
        custom_url = "http://localhost:11434"
        client.ollama_host = custom_url

        try:
            await client._check_ollama_server()
            print_fail("Expected OllamaConnectionError but no exception was raised")
            tests_failed += 1
        except OllamaConnectionError as e:
            error_msg = str(e)

            if custom_url in error_msg:
                print_pass(f"Server URL ({custom_url}) included in error message")
                tests_passed += 1
            else:
                print_fail(f"Server URL ({custom_url}) not in error message")
                tests_failed += 1

    except Exception as e:
        print_fail(f"Test setup failed: {e}")
        tests_failed += 1

    print_test("Error message mentions installation instructions")
    try:
        client = TranscriptionClient(model="whisper")
        client.ollama_host = "http://localhost:9999"

        try:
            await client._check_ollama_server()
            print_fail("Expected OllamaConnectionError but no exception was raised")
            tests_failed += 1
        except OllamaConnectionError as e:
            error_msg = str(e)

            # Check for installation-related keywords
            install_keywords = ["install", "download", "ollama.ai"]
            has_install_info = any(keyword in error_msg.lower() for keyword in install_keywords)

            if has_install_info:
                print_pass("Error message includes installation information")
                tests_passed += 1
            else:
                print_fail("Error message missing installation information")
                tests_failed += 1

    except Exception as e:
        print_fail(f"Test setup failed: {e}")
        tests_failed += 1

    print(f"\n{GREEN}Passed:{RESET} {tests_passed}/{tests_passed + tests_failed}")
    return tests_passed, tests_failed

async def verify_transcribe_error_handling():
    """Verify transcribe() method properly handles Ollama server errors."""
    print_section("PART 3: transcribe() Error Handling")

    tests_passed = 0
    tests_failed = 0

    print_test("transcribe() raises TranscriptionError when server not running")
    try:
        client = TranscriptionClient(model="whisper")
        client.ollama_host = "http://localhost:9999"  # Wrong port

        # Create a dummy audio file for testing
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            temp_audio = Path(f.name)
            # Write minimal WAV header
            f.write(b"RIFF" + b"\x00" * 36 + b"WAVE")

        try:
            result = await client.transcribe(audio_path=temp_audio)
            print_fail("Expected TranscriptionError but got result")
            tests_failed += 1
        except TranscriptionError as e:
            print_pass(f"TranscriptionError raised as expected: {type(e).__name__}")
            tests_passed += 1
        except Exception as e:
            print_fail(f"Wrong exception type: {type(e).__name__}")
            tests_failed += 1
        finally:
            # Clean up temp file
            if temp_audio.exists():
                temp_audio.unlink()

    except Exception as e:
        print_fail(f"Test setup failed: {e}")
        tests_failed += 1

    print_test("transcribe() error message includes Ollama details")
    try:
        client = TranscriptionClient(model="whisper")
        client.ollama_host = "http://localhost:9999"

        # Create a dummy audio file for testing
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            temp_audio = Path(f.name)
            f.write(b"RIFF" + b"\x00" * 36 + b"WAVE")

        try:
            result = await client.transcribe(audio_path=temp_audio)
            print_fail("Expected TranscriptionError but got result")
            tests_failed += 1
        except TranscriptionError as e:
            error_msg = str(e)

            # Check if Ollama is mentioned in the error
            if "ollama" in error_msg.lower():
                print_pass("Error message mentions Ollama")
                tests_passed += 1
            else:
                print_fail("Error message doesn't mention Ollama")
                tests_failed += 1
        finally:
            # Clean up temp file
            if temp_audio.exists():
                temp_audio.unlink()

    except Exception as e:
        print_fail(f"Test setup failed: {e}")
        tests_failed += 1

    print(f"\n{GREEN}Passed:{RESET} {tests_passed}/{tests_passed + tests_failed}")
    return tests_passed, tests_failed

async def verify_is_model_downloaded_error_handling():
    """Verify is_model_downloaded() handles server errors gracefully."""
    print_section("PART 4: is_model_downloaded() Error Handling")

    tests_passed = 0
    tests_failed = 0

    print_test("is_model_downloaded() returns False when server not running")
    try:
        client = TranscriptionClient(model="whisper")
        client.ollama_host = "http://localhost:9999"  # Wrong port

        result = await client.is_model_downloaded("whisper")

        if result is False:
            print_pass("is_model_downloaded() returns False when server unavailable")
            tests_passed += 1
        else:
            print_fail(f"is_model_downloaded() returned {result}, expected False")
            tests_failed += 1

    except Exception as e:
        print_fail(f"is_model_downloaded() raised exception instead of returning False: {e}")
        tests_failed += 1

    print_test("is_model_downloaded() doesn't raise exception on connection error")
    try:
        client = TranscriptionClient(model="whisper")
        client.ollama_host = "http://localhost:9999"

        # Should return False, not raise exception
        result = await client.is_model_downloaded("whisper")
        print_pass("is_model_downloaded() handles connection error gracefully")
        tests_passed += 1

    except Exception as e:
        print_fail(f"is_model_downloaded() raised exception: {e}")
        tests_failed += 1

    print(f"\n{GREEN}Passed:{RESET} {tests_passed}/{tests_passed + tests_failed}")
    return tests_passed, tests_failed

def print_manual_testing_instructions():
    """Print manual testing instructions."""
    print_section("MANUAL TESTING INSTRUCTIONS")

    print(f"""
{YELLOW}Manual End-to-End Testing:{RESET}

To verify Ollama server error handling in the complete application:

{GREEN}Test 1: Server Not Running Error{RESET}
1. Ensure Ollama server is NOT running:
   - Check: ps aux | grep ollama
   - If running: killall ollama
2. Launch the Hex application
3. Try to start a recording (press hotkey)
4. Verify: A helpful error message is displayed with:
   - Clear explanation: "Cannot connect to Ollama server"
   - Server URL: http://localhost:11434
   - Numbered solutions (at least 3):
     1. Start Ollama server: 'ollama serve'
     2. Verify installation: https://ollama.ai/download
     3. Check firewall/port 11434
   - No technical jargon that confuses users

{GREEN}Test 2: Server Starts Later{RESET}
1. Start with Ollama server NOT running
2. Verify error message appears
3. Start Ollama server in terminal: ollama serve
4. Try recording again
5. Verify: Recording works now, no error

{GREEN}Test 3: Wrong Server URL{RESET}
1. Edit settings to use wrong URL (e.g., http://localhost:9999)
2. Try to start recording
3. Verify: Error message mentions the wrong URL
4. Change URL back to correct value
5. Verify: Recording works again

{GREEN}Test 4: Model Not Downloaded{RESET}
1. Start Ollama server
2. Delete a model: ollama rm whisper
3. Try to transcribe with that model
4. Verify: Different error about missing model (not connection error)
5. Pull model: ollama pull whisper
6. Verify: Recording works again

{GREEN}Success Criteria:{RESET}
✓ Error messages are clear and non-technical
✓ Error messages include actionable steps
✓ Error messages mention Ollama installation URL
✓ Error messages show the server URL being accessed
✓ No unhelpful technical errors (e.g., raw stack traces)
✓ After fixing the issue, recording works without app restart
""")

async def main():
    """Run all verification tests."""
    print_section("Ollama Server Error Handling Verification")

    if not DEPENDENCIES_AVAILABLE:
        print(f"{RED}ERROR: Missing required dependencies{RESET}\n")
        print(f"Cannot import vox.clients.transcription:")
        print(f"  {IMPORT_ERROR}\n")
        print(f"{YELLOW}Skipping automated tests...{RESET}\n")
        print_manual_testing_instructions()
        print(f"\n{YELLOW}To run automated tests, install dependencies:{RESET}")
        print(f"  pip install -e .")
        return 1

    print_info("This script verifies that Ollama server errors are handled gracefully")
    print_info("with helpful, actionable error messages.\n")

    total_passed = 0
    total_failed = 0

    # Run all test parts
    passed, failed = await verify_server_check_raises_error()
    total_passed += passed
    total_failed += failed

    passed, failed = await verify_error_message_quality()
    total_passed += passed
    total_failed += failed

    passed, failed = await verify_transcribe_error_handling()
    total_passed += passed
    total_failed += failed

    passed, failed = await verify_is_model_downloaded_error_handling()
    total_passed += passed
    total_failed += failed

    # Print summary
    print_section("SUMMARY")
    total_tests = total_passed + total_failed
    print(f"Total tests: {total_tests}")
    print(f"{GREEN}Passed: {total_passed}{RESET}")
    print(f"{RED}Failed: {total_failed}{RESET}")

    if total_failed == 0:
        print(f"\n{GREEN}✓ All automated tests passed!{RESET}\n")
    else:
        print(f"\n{RED}✗ Some tests failed{RESET}\n")

    # Print manual testing instructions
    print_manual_testing_instructions()

    return 0 if total_failed == 0 else 1

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
