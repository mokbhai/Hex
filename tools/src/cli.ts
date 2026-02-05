#!/usr/bin/env bun
/**
 * Hex Release CLI
 *
 * Automates the release process:
 * 1. Checks for clean working tree
 * 2. Applies changesets and bumps version
 * 3. Syncs changelog
 * 4. Updates Info.plist and project.pbxproj
 * 5. Builds, signs, and notarizes the app
 * 6. Creates DMG and ZIP
 * 7. Uploads to S3
 * 8. Commits, tags, and pushes
 * 9. Creates GitHub release
 *
 * Usage:
 *   bun run tools/src/cli.ts release
 */

import { config } from "dotenv";
import { resolve, join } from "path";
import { existsSync, readFileSync, writeFileSync, readdirSync } from "fs";
import { $ } from "bun";

// Load .env from project root
const projectRoot = resolve(import.meta.dir, "../..");
config({ path: join(projectRoot, ".env") });

// Colors for terminal output
const colors = {
  reset: "\x1b[0m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m",
  dim: "\x1b[2m",
};

function log(msg: string) {
  console.log(msg);
}

function info(msg: string) {
  console.log(`${colors.blue}ℹ${colors.reset} ${msg}`);
}

function success(msg: string) {
  console.log(`${colors.green}✓${colors.reset} ${msg}`);
}

function warn(msg: string) {
  console.log(`${colors.yellow}⚠${colors.reset} ${msg}`);
}

function error(msg: string) {
  console.error(`${colors.red}✗${colors.reset} ${msg}`);
}

function step(msg: string) {
  console.log(`\n${colors.cyan}→${colors.reset} ${msg}`);
}

// Check required environment variables
function checkEnv(): { awsKeyId: string; awsSecretKey: string } {
  const awsKeyId = process.env.AWS_ACCESS_KEY_ID;
  const awsSecretKey = process.env.AWS_SECRET_ACCESS_KEY;
  const awsEndpoint = process.env.AWS_ENDPOINT;

  if (!awsKeyId || !awsSecretKey) {
    error("Missing required environment variables:");
    if (!awsKeyId) error("  - AWS_ACCESS_KEY_ID");
    if (!awsSecretKey) error("  - AWS_SECRET_ACCESS_KEY");
    log("");
    info("Set them in .env file or export them:");
    log("  export AWS_ACCESS_KEY_ID=your-key-id");
    log("  export AWS_SECRET_ACCESS_KEY=your-secret-key");
    process.exit(1);
  }

  success("AWS credentials loaded");
  if (awsEndpoint) {
    info(`Using custom endpoint: ${awsEndpoint}`);
  }
  return { awsKeyId, awsSecretKey };
}

// Check if working tree is clean
async function checkCleanWorkingTree(): Promise<void> {
  const result = await $`git status --porcelain`.text();
  if (result.trim()) {
    error("Working tree is not clean. Please commit or stash changes first.");
    log("");
    log(result);
    process.exit(1);
  }
  success("Working tree is clean");
}

// Check for pending changesets
async function checkChangesets(): Promise<boolean> {
  const changesetDir = join(projectRoot, ".changeset");
  if (!existsSync(changesetDir)) {
    return false;
  }

  const files = readdirSync(changesetDir).filter(
    (f) => f.endsWith(".md") && f !== "README.md"
  );
  return files.length > 0;
}

// Get current version from package.json
function getCurrentVersion(): string {
  const pkgPath = join(projectRoot, "package.json");
  const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
  return pkg.version;
}

// Update version in project.pbxproj
function updatePbxproj(version: string, buildNumber: number): void {
  const pbxprojPath = join(
    projectRoot,
    "Hex.xcodeproj/project.pbxproj"
  );
  let content = readFileSync(pbxprojPath, "utf-8");

  // Update MARKETING_VERSION
  content = content.replace(
    /MARKETING_VERSION = [\d.]+;/g,
    `MARKETING_VERSION = ${version};`
  );

  // Update CURRENT_PROJECT_VERSION
  content = content.replace(
    /CURRENT_PROJECT_VERSION = \d+;/g,
    `CURRENT_PROJECT_VERSION = ${buildNumber};`
  );

  writeFileSync(pbxprojPath, content);
}

// Get current build number from project.pbxproj
function getCurrentBuildNumber(): number {
  const pbxprojPath = join(
    projectRoot,
    "Hex.xcodeproj/project.pbxproj"
  );
  const content = readFileSync(pbxprojPath, "utf-8");
  const match = content.match(/CURRENT_PROJECT_VERSION = (\d+);/);
  return match ? parseInt(match[1], 10) : 1;
}

// Sync changelog to Hex/Resources/changelog.md
async function syncChangelog(): Promise<void> {
  const srcPath = join(projectRoot, "CHANGELOG.md");
  const destPath = join(projectRoot, "Hex/Resources/changelog.md");

  if (existsSync(srcPath)) {
    const content = readFileSync(srcPath, "utf-8");
    writeFileSync(destPath, content);
    success("Synced changelog to Hex/Resources/changelog.md");
  }
}

// Build the app
async function buildApp(): Promise<string> {
  step("Cleaning DerivedData...");
  await $`rm -rf ~/Library/Developer/Xcode/DerivedData/Hex-*`.quiet();

  step("Building archive...");
  const archivePath = join(projectRoot, "build/Hex.xcarchive");
  await $`xcodebuild -scheme Hex -configuration Release -archivePath ${archivePath} archive`.quiet();

  success("Archive created");
  return archivePath;
}

// Export the app
async function exportApp(archivePath: string): Promise<string> {
  step("Exporting app...");

  const exportOptionsPath = join(projectRoot, "build/ExportOptions.plist");
  const signingMethod = process.env.SIGNING_METHOD || "development"; // "development" or "developer-id"

  const exportOptions = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${signingMethod}</string>
    ${process.env.TEAM_ID ? `<key>teamID</key>
    <string>${process.env.TEAM_ID}</string>` : ""}
</dict>
</plist>`;

  writeFileSync(exportOptionsPath, exportOptions);

  const exportPath = join(projectRoot, "build/export");
  await $`xcodebuild -exportArchive -archivePath ${archivePath} -exportPath ${exportPath} -exportOptionsPlist ${exportOptionsPath}`.quiet();

  const appPath = join(exportPath, "Hex.app");
  success(`App exported (${signingMethod} signing)`);
  return appPath;
}

// Notarize the app (skipped for development signing)
async function notarizeApp(appPath: string): Promise<void> {
  const signingMethod = process.env.SIGNING_METHOD || "development";

  if (signingMethod === "development") {
    info("Skipping notarization (development signing)");
    return;
  }

  step("Notarizing app...");

  const zipPath = join(projectRoot, "build/Hex-notarize.zip");
  await $`ditto -c -k --keepParent ${appPath} ${zipPath}`.quiet();

  // Use keychain profile locally, env vars in CI
  if (process.env.GITHUB_ACTIONS) {
    await $`xcrun notarytool submit ${zipPath} --apple-id ${process.env.APPLE_ID} --password ${process.env.APPLE_ID_PASSWORD} --team-id ${process.env.TEAM_ID} --wait`.quiet();
  } else {
    await $`xcrun notarytool submit ${zipPath} --keychain-profile "AC_PASSWORD" --wait`.quiet();
  }

  // Staple the notarization
  await $`xcrun stapler staple ${appPath}`.quiet();

  success("App notarized and stapled");
}

// Create DMG
async function createDmg(appPath: string, version: string): Promise<string> {
  step("Creating DMG...");

  const updatesDir = join(projectRoot, "updates");
  await $`mkdir -p ${updatesDir}`.quiet();

  const dmgPath = join(updatesDir, `Hex-${version}.dmg`);
  const signingMethod = process.env.SIGNING_METHOD || "development";

  // Create DMG with create-dmg if available, otherwise use hdiutil
  try {
    await $`create-dmg --volname "Hex" --window-pos 200 120 --window-size 600 400 --icon-size 100 --icon "Hex.app" 175 190 --hide-extension "Hex.app" --app-drop-link 425 190 ${dmgPath} ${appPath}`.quiet();
  } catch {
    // Fallback to hdiutil
    await $`hdiutil create -volname "Hex" -srcfolder ${appPath} -ov -format UDZO ${dmgPath}`.quiet();
  }

  if (signingMethod === "developer-id") {
    // Sign the DMG
    await $`codesign --force --sign "Developer ID Application" ${dmgPath}`.quiet();

    // Notarize the DMG
    if (process.env.GITHUB_ACTIONS) {
      await $`xcrun notarytool submit ${dmgPath} --apple-id ${process.env.APPLE_ID} --password ${process.env.APPLE_ID_PASSWORD} --team-id ${process.env.TEAM_ID} --wait`.quiet();
    } else {
      await $`xcrun notarytool submit ${dmgPath} --keychain-profile "AC_PASSWORD" --wait`.quiet();
    }

    await $`xcrun stapler staple ${dmgPath}`.quiet();
  } else {
    info("Skipping DMG signing/notarization (development signing)");
  }

  // Create latest symlink
  const latestDmgPath = join(updatesDir, "hex-latest.dmg");
  await $`cp ${dmgPath} ${latestDmgPath}`.quiet();

  success(`DMG created: ${dmgPath}`);
  return dmgPath;
}

// Create ZIP for Homebrew
async function createZip(appPath: string, version: string): Promise<string> {
  step("Creating ZIP for Homebrew...");

  const updatesDir = join(projectRoot, "updates");
  const zipPath = join(updatesDir, `Hex-${version}.zip`);

  await $`ditto -c -k --keepParent ${appPath} ${zipPath}`.quiet();

  success(`ZIP created: ${zipPath}`);
  return zipPath;
}

// Generate Sparkle appcast
async function generateAppcast(): Promise<void> {
  step("Generating Sparkle appcast...");

  const updatesDir = join(projectRoot, "updates");
  const generateAppcast = join(projectRoot, "bin/generate_appcast");

  if (existsSync(generateAppcast)) {
    await $`${generateAppcast} --maximum-deltas 3 ${updatesDir}`.quiet();
    success("Appcast generated");
  } else {
    warn("generate_appcast not found, skipping appcast generation");
  }
}

// Upload to S3
async function uploadToS3(version: string): Promise<void> {
  step("Uploading to S3...");

  const updatesDir = join(projectRoot, "updates");
  const bucket = process.env.S3_BUCKET || process.env.AWS_S3_BUCKET || "hex-updates";
  const endpoint = process.env.AWS_ENDPOINT;

  const region = process.env.AWS_REGION || "us-east-1";
  const forcePathStyle = process.env.AWS_FORCE_PATH_STYLE === "true";

  // Build extra args for aws cli
  const extraArgs: string[] = [];
  if (endpoint) extraArgs.push("--endpoint-url", endpoint);
  if (region) extraArgs.push("--region", region);
  if (forcePathStyle) extraArgs.push("--no-verify-ssl"); // Path style often used with self-hosted

  // Upload versioned DMG
  await $`aws s3 cp ${join(updatesDir, `Hex-${version}.dmg`)} s3://${bucket}/Hex-${version}.dmg --acl public-read ${extraArgs}`.quiet();

  // Upload latest DMG
  await $`aws s3 cp ${join(updatesDir, "hex-latest.dmg")} s3://${bucket}/hex-latest.dmg --acl public-read ${extraArgs}`.quiet();

  // Upload ZIP
  await $`aws s3 cp ${join(updatesDir, `Hex-${version}.zip`)} s3://${bucket}/Hex-${version}.zip --acl public-read ${extraArgs}`.quiet();

  // Upload appcast
  const appcastPath = join(updatesDir, "appcast.xml");
  if (existsSync(appcastPath)) {
    await $`aws s3 cp ${appcastPath} s3://${bucket}/appcast.xml --acl public-read ${extraArgs}`.quiet();
  }

  success(`Uploaded to S3${endpoint ? ` (${endpoint})` : ""}`);
}

// Commit and tag
async function commitAndTag(version: string): Promise<void> {
  step("Committing version changes...");

  await $`git add -A`.quiet();
  await $`git commit -m "Release ${version}"`.quiet();
  await $`git tag v${version}`.quiet();
  await $`git push origin HEAD --tags`.quiet();

  success(`Tagged and pushed v${version}`);
}

// Create GitHub release
async function createGitHubRelease(
  version: string,
  dmgPath: string,
  zipPath: string
): Promise<void> {
  step("Creating GitHub release...");

  const changelogPath = join(projectRoot, "CHANGELOG.md");
  let releaseNotes = `Release ${version}`;

  if (existsSync(changelogPath)) {
    const changelog = readFileSync(changelogPath, "utf-8");
    // Extract notes for this version
    const versionHeader = `## ${version}`;
    const startIndex = changelog.indexOf(versionHeader);
    if (startIndex !== -1) {
      const endIndex = changelog.indexOf("\n## ", startIndex + 1);
      releaseNotes =
        endIndex !== -1
          ? changelog.slice(startIndex, endIndex).trim()
          : changelog.slice(startIndex).trim();
    }
  }

  const notesFile = join(projectRoot, "build/release-notes.md");
  writeFileSync(notesFile, releaseNotes);

  await $`gh release create v${version} --title "Hex v${version}" --notes-file ${notesFile} ${dmgPath} ${zipPath}`.quiet();

  success(`GitHub release created: v${version}`);
}

// Main release function
async function release(): Promise<void> {
  log("");
  log(`${colors.cyan}╔════════════════════════════════════╗${colors.reset}`);
  log(`${colors.cyan}║      Hex Release Tool              ║${colors.reset}`);
  log(`${colors.cyan}╚════════════════════════════════════╝${colors.reset}`);
  log("");

  // Check environment
  step("Checking environment...");
  checkEnv();

  // Check working tree
  step("Checking working tree...");
  await checkCleanWorkingTree();

  // Check for changesets
  const skipChangeset = process.env.SKIP_CHANGESET === "true" || process.argv.includes("--skip-changeset");

  if (!skipChangeset) {
    step("Checking for changesets...");
    const hasChangesets = await checkChangesets();

    if (!hasChangesets) {
      warn("No changesets found.");
      info("Create one with: bun run changeset:add-ai patch \"Your summary\"");
      info("Or run with SKIP_CHANGESET=true to skip this check");

      const response = prompt("Continue with manual version bump? (y/N) ");
      if (response?.toLowerCase() !== "y") {
        log("Aborting release.");
        process.exit(0);
      }
    } else {
      // Apply changesets
      step("Applying changesets...");
      await $`bun run changeset version`.quiet();
      success("Changesets applied");
    }
  } else {
    info("Skipping changeset check");
  }

  // Get version
  const version = getCurrentVersion();
  const buildNumber = getCurrentBuildNumber() + 1;

  info(`Version: ${version}`);
  info(`Build number: ${buildNumber}`);

  // Update project files
  step("Updating project files...");
  updatePbxproj(version, buildNumber);
  success("Updated project.pbxproj");

  // Sync changelog
  await syncChangelog();

  // Build
  const archivePath = await buildApp();

  // Export
  const appPath = await exportApp(archivePath);

  // Notarize
  await notarizeApp(appPath);

  // Create artifacts
  const dmgPath = await createDmg(appPath, version);
  const zipPath = await createZip(appPath, version);

  // Generate appcast
  await generateAppcast();

  // Upload to S3
  await uploadToS3(version);

  // Commit and tag
  await commitAndTag(version);

  // Create GitHub release
  await createGitHubRelease(version, dmgPath, zipPath);

  log("");
  log(`${colors.green}════════════════════════════════════${colors.reset}`);
  log(`${colors.green}  Release ${version} complete!${colors.reset}`);
  log(`${colors.green}════════════════════════════════════${colors.reset}`);
  log("");
}

// CLI entry point
const command = process.argv[2];

if (command === "release") {
  release().catch((err) => {
    error(err.message);
    process.exit(1);
  });
} else {
  log("Hex Release CLI");
  log("");
  log("Usage:");
  log("  bun run tools/src/cli.ts release    Run the release process");
  log("");
  log("Environment variables (can be set in .env):");
  log("  AWS_ACCESS_KEY_ID       AWS access key for S3 uploads");
  log("  AWS_SECRET_ACCESS_KEY   AWS secret key for S3 uploads");
  log("  AWS_ENDPOINT            Custom S3 endpoint (for R2, MinIO, etc.)");
  log("  AWS_REGION              AWS region (default: us-east-1)");
  log("  AWS_FORCE_PATH_STYLE    Use path-style URLs (default: false)");
  log("  S3_BUCKET               S3 bucket name (default: hex-updates)");
  log("  TEAM_ID                 Apple Team ID (for CI)");
  log("  APPLE_ID                Apple ID (for CI notarization)");
  log("  APPLE_ID_PASSWORD       App-specific password (for CI)");
}
