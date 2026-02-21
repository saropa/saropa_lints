# --- Script Changelog ---
# v4.0.0 (2026-02-21)
# - Added: Flutter SDK release notes scraper (docs.flutter.dev).
# - Changed: Script now runs both Dart-Code and Flutter SDK scrapers.
# - Added: Separate output directories for each source.
# v3.1.0 (2026-02-21)
# - Changed: Output split into per-version files under versions/ subdirectory.
# - Added: Index file (all_features_report.md) with links to each version file.
# v3.0.0 (2026-02-21)
# - Added: GitHub issue detail fetching via `gh api` (requires gh CLI auth).
# - Added: JSON cache file to avoid re-fetching issues across runs.
# - Added: Inline issue body expansion beneath each feature entry.
# - Added: Second progress bar for GitHub fetch phase.
# v2.0.0 (2026-02-20)
# - REWRITE: Moved away from the GitHub API (which caused 404s due to invalid repo paths).
# - Added: Live HTML scraping directly from dartcode.org.
# - Added: beautifulsoup4 and html2text dependencies for accurate DOM parsing and Markdown generation.
# - Changed: Extraction logic dynamically filters out "Fixes" and "Upstream" headers
#   from the live site, making it highly accurate and rate-limit free.
# ------------------------

import sys
import subprocess

# --- Dependency Management ---
def install_and_import(package_name, import_name=None):
    if import_name is None:
        import_name = package_name
    try:
        __import__(import_name)
    except ImportError:
        print(f"\n[System] Package '{package_name}' not found. Installing via pip...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", package_name])
            print(f"[System] Successfully installed '{package_name}'.\n")
        except subprocess.CalledProcessError as e:
            print(f"[Error] Failed to install {package_name}. Please install it manually: {e}")
            sys.exit(1)

install_and_import("requests")
install_and_import("rich")
install_and_import("beautifulsoup4", "bs4")
install_and_import("html2text")

import json
import os
import re
import logging
import shutil
import time
from datetime import datetime
from typing import Dict, List, Optional, Set, Tuple

import requests
from bs4 import BeautifulSoup
import html2text
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
from rich.table import Table
from rich.panel import Panel

# --- Configuration & Setup ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(BASE_DIR)
REPORTS_DIR = os.path.join(PROJECT_DIR, "reports")
CACHE_DIR = os.path.join(REPORTS_DIR, "_cache")
EXTRACT_FILE = "all_features_report.md"

# Dart-Code (VS Code extension)
DARTCODE_BASE_URL = "https://dartcode.org"
DARTCODE_REPO = "Dart-Code/Dart-Code"
DARTCODE_OUTPUT_DIR = os.path.join(CACHE_DIR, "dart_code_exports")

# Flutter SDK
FLUTTER_BASE_URL = "https://docs.flutter.dev"
FLUTTER_REPO = "flutter/flutter"
FLUTTER_OUTPUT_DIR = os.path.join(CACHE_DIR, "flutter_sdk_exports")

# Dart SDK
DART_SDK_CHANGELOG_URL = "https://raw.githubusercontent.com/dart-lang/sdk/main/CHANGELOG.md"
DART_SDK_OUTPUT_DIR = os.path.join(CACHE_DIR, "dart_sdk_exports")

console = Console()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)


# --- GitHub Issue Fetcher ---
class IssueFetcher:
    """Fetches GitHub issue details via `gh api` with local JSON caching."""

    def __init__(self, repo: str, cache_path: str):
        self.repo = repo
        self.cache_path = cache_path
        self.cache: Dict[str, dict] = self._load_cache()
        self.gh_available = self._check_gh()
        self.fetch_count = 0
        self.cache_hit_count = 0

    def _check_gh(self) -> bool:
        try:
            result = subprocess.run(
                ["gh", "auth", "status"],
                capture_output=True, text=True, timeout=10,
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False

    def _load_cache(self) -> Dict[str, dict]:
        if os.path.exists(self.cache_path):
            try:
                with open(self.cache_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except (json.JSONDecodeError, OSError):
                pass
        return {}

    def save_cache(self):
        with open(self.cache_path, "w", encoding="utf-8") as f:
            json.dump(self.cache, f, indent=2, ensure_ascii=False)

    def fetch_issue(self, issue_num: str) -> Optional[dict]:
        """Fetch a single issue. Returns cached data if available."""
        if issue_num in self.cache:
            self.cache_hit_count += 1
            return self.cache[issue_num]

        if not self.gh_available:
            return None

        try:
            result = subprocess.run(
                [
                    "gh", "api",
                    f"repos/{self.repo}/issues/{issue_num}",
                    "--jq",
                    '{title: .title, state: .state, labels: [.labels[].name], body: .body}',
                ],
                capture_output=True, text=True, timeout=15,
                encoding='utf-8', errors='replace',
            )
            if result.returncode != 0:
                logging.warning(f"gh api failed for #{issue_num}: {result.stderr.strip()}")
                return None

            data = json.loads(result.stdout)
            self.cache[issue_num] = data
            self.fetch_count += 1

            # Save cache every 50 fetches
            if self.fetch_count % 50 == 0:
                self.save_cache()

            return data

        except (subprocess.TimeoutExpired, json.JSONDecodeError, OSError) as e:
            logging.warning(f"Error fetching #{issue_num}: {e}")
            return None

    def fetch_batch(self, issue_nums: List[str], progress=None, task_id=None):
        """Fetch a batch of issues, updating progress bar."""
        for num in issue_nums:
            self.fetch_issue(num)
            if progress and task_id is not None:
                progress.advance(task_id)
        self.save_cache()


def extract_issue_numbers(text: str, repo: str) -> List[str]:
    """Extract unique issue/PR numbers from markdown text for a given repo."""
    # Match both /issues/N and /pull/N URLs
    escaped = re.escape(repo)
    pattern = rf'github\.com/{escaped}/(?:issues|pull)/(\d+)'
    return list(dict.fromkeys(re.findall(pattern, text)))


def truncate_body(body: str, max_chars: int = 1000) -> str:
    """Truncate issue body to a reasonable length."""
    if not body:
        return ""
    # Strip HTML tags that sometimes appear in issue bodies
    body = re.sub(r'<[^>]+>', '', body)
    # Normalize whitespace
    body = re.sub(r'\n{3,}', '\n\n', body.strip())
    if len(body) <= max_chars:
        return body
    # Cut at last paragraph/sentence boundary before limit
    truncated = body[:max_chars]
    last_para = truncated.rfind('\n\n')
    if last_para > max_chars // 2:
        truncated = truncated[:last_para]
    return truncated + "\n\n_(truncated)_"


def enrich_feature_text(feature_md: str, fetcher: IssueFetcher) -> str:
    """Insert issue details beneath each feature line that references issues/PRs."""
    lines = feature_md.split('\n')
    enriched = []
    escaped = re.escape(fetcher.repo)
    pattern = rf'github\.com/{escaped}/(?:issues|pull)/(\d+)'

    for line in lines:
        enriched.append(line)

        # Find issue/PR refs on this line
        issue_nums = re.findall(pattern, line)
        if not issue_nums:
            continue

        # Use the first issue as the primary (usually the feature request)
        primary = fetcher.cache.get(issue_nums[0])
        if not primary or not primary.get('body'):
            continue

        body = truncate_body(primary['body'])
        if not body:
            continue

        labels = primary.get('labels', [])
        label_str = f" `{'` `'.join(labels)}`" if labels else ""

        # Add detail block as a blockquote beneath the feature line
        enriched.append("")
        enriched.append(f"  > **#{issue_nums[0]}**: {primary.get('title', '')}{label_str}")
        for body_line in body.split('\n'):
            enriched.append(f"  > {body_line}")
        enriched.append("")

    return '\n'.join(enriched)


class DartCodeScraper:
    def __init__(self, start_version: str, fetch_issues: bool = True):
        self.start_version_str = start_version
        self.start_version_tuple = self._parse_version_string(start_version)
        self.session = requests.Session()
        self.fetch_issues = fetch_issues

    def _parse_version_string(self, version_str: str) -> Tuple[int, int]:
        match = re.search(r'v(\d+)[-.](\d+)', version_str)
        if match:
            return (int(match.group(1)), int(match.group(2)))
        return (0, 0)

    def fetch_version_links(self) -> List[Tuple[str, str]]:
        """Scrapes dartcode.org/releases/ to find all valid version URLs."""
        logging.info("Requesting version list from dartcode.org...")
        try:
            response = self.session.get(f"{DARTCODE_BASE_URL}/releases/")
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')

            versions = []
            seen = set()

            for a in soup.find_all('a', href=True):
                href = a['href']
                match = re.search(r'/releases/(v\d+-\d+)/?', href)
                if match:
                    v_str = match.group(1)
                    if v_str not in seen:
                        seen.add(v_str)
                        url = f"{DARTCODE_BASE_URL}/releases/{v_str}/"
                        versions.append((v_str, url))

            versions.sort(key=lambda x: self._parse_version_string(x[0]), reverse=True)
            return versions
        except Exception as e:
            console.print(f"[bold red]Error fetching version list:[/bold red] {e}")
            logging.error(f"Failed to fetch version list: {e}")
            return []

    def clean_html_to_markdown(self, html_content: str) -> str:
        """Extracts the core content from the HTML and converts it to Markdown."""
        soup = BeautifulSoup(html_content, 'html.parser')

        content_container = (
            soup.find('div', class_='page-content')
            or soup.find('main')
            or soup.find('article')
            or soup.body
        )

        if content_container == soup.body:
            for tag in soup.find_all(['nav', 'header', 'footer']):
                tag.decompose()

        h = html2text.HTML2Text()
        h.ignore_links = False
        h.body_width = 0

        md_text = h.handle(str(content_container))

        lines = md_text.split('\n')
        filtered_lines = []

        for line in lines:
            if re.match(r'^#+\s*(Fixes|Upstream|Known Issues|Requirements|Changes)', line, re.IGNORECASE):
                break
            filtered_lines.append(line)

        return '\n'.join(filtered_lines).strip()

    def run(self):
        mode_label = "with GitHub details" if self.fetch_issues else "features only"
        intro_text = (
            f"[bold blue]Dart-Code Release Scraper[/bold blue] ({mode_label})\n"
            f"Targeting: [green]{self.start_version_str}[/green] and newer"
        )
        console.print(Panel(intro_text, expand=False), justify="center")

        all_versions = self.fetch_version_links()
        target_versions = []

        for v_str, url in all_versions:
            v_tuple = self._parse_version_string(v_str)
            if v_tuple < self.start_version_tuple:
                break
            target_versions.append((v_str, url))

        if not target_versions:
            console.print("[yellow]No versions found matching your criteria.[/yellow]")
            return

        # --- Phase 1: Scrape dartcode.org ---
        version_features: Dict[str, str] = {}

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=console,
        ) as progress:
            task = progress.add_task("[cyan]Scraping dartcode.org...", total=len(target_versions))

            for v_str, url in target_versions:
                progress.update(task, description=f"[cyan]Scraping {v_str}...")
                try:
                    res = self.session.get(url)
                    res.raise_for_status()
                    version_features[v_str] = self.clean_html_to_markdown(res.text)
                    logging.info(f"Scraped {v_str}")
                except Exception as e:
                    logging.error(f"Error scraping {v_str}: {e}")
                    version_features[v_str] = "> [!ERROR] Failed to fetch content."
                progress.advance(task)

        # --- Phase 2: Fetch GitHub issue details ---
        fetcher = None
        if self.fetch_issues:
            cache_path = os.path.join(DARTCODE_OUTPUT_DIR, "issue_cache.json")
            fetcher = IssueFetcher(DARTCODE_REPO, cache_path)

            if not fetcher.gh_available:
                console.print("[yellow]gh CLI not authenticated — skipping issue details.[/yellow]")
                fetcher = None
            else:
                # Collect all unique issue numbers across all versions
                all_issue_nums: Set[str] = set()
                for features in version_features.values():
                    all_issue_nums.update(extract_issue_numbers(features, DARTCODE_REPO))

                # Filter to only uncached issues
                uncached = [n for n in all_issue_nums if n not in fetcher.cache]
                cached_count = len(all_issue_nums) - len(uncached)

                console.print(
                    f"\n[dim]Issues: {len(all_issue_nums)} total, "
                    f"{cached_count} cached, {len(uncached)} to fetch[/dim]"
                )

                if uncached:
                    with Progress(
                        SpinnerColumn(),
                        TextColumn("[progress.description]{task.description}"),
                        BarColumn(),
                        TaskProgressColumn(),
                        console=console,
                    ) as progress:
                        task = progress.add_task(
                            "[green]Fetching GitHub issues...",
                            total=len(uncached),
                        )
                        fetcher.fetch_batch(uncached, progress, task)

                    console.print(
                        f"[dim]Fetched {fetcher.fetch_count} issues, "
                        f"cache saved to issue_cache.json[/dim]"
                    )

        # --- Phase 3: Write per-version files + index ---
        os.makedirs(DARTCODE_OUTPUT_DIR, exist_ok=True)
        versions_dir = os.path.join(DARTCODE_OUTPUT_DIR, "versions")
        os.makedirs(versions_dir, exist_ok=True)

        version_files = []
        for v_str, _ in target_versions:
            features = version_features.get(v_str, "")
            issue_count = len(extract_issue_numbers(features, DARTCODE_REPO))
            if fetcher:
                features = enrich_feature_text(features, fetcher)

            filename = f"{v_str}.md"
            filepath = os.path.join(versions_dir, filename)
            with open(filepath, "w", encoding="utf-8") as vf:
                vf.write(f"# Dart-Code {v_str}\n\n")
                vf.write(features)
                vf.write("\n")

            version_files.append((v_str, filename, issue_count))

        # Write index file
        index_path = os.path.join(DARTCODE_OUTPUT_DIR, EXTRACT_FILE)
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(index_path, "w", encoding="utf-8") as idx:
            idx.write("# Dart-Code Feature Archive\n\n")
            idx.write(f"Generated on: {timestamp}\n")
            idx.write(f"Version Range: {target_versions[0][0]} down to {target_versions[-1][0]}\n")
            if fetcher:
                idx.write("Includes: GitHub issue details (expanded inline)\n")
            idx.write("\n---\n\n")
            idx.write("| Version | Issues | File |\n")
            idx.write("|---------|--------|------|\n")
            for v_str, filename, issue_count in version_files:
                idx.write(f"| {v_str} | {issue_count} | [versions/{filename}](versions/{filename}) |\n")

        self.display_summary(target_versions, fetcher, len(version_files))

    def display_summary(self, processed_versions, fetcher: Optional[IssueFetcher], file_count: int):
        table = Table(title="Dart-Code Extraction Summary")
        table.add_column("Output Folder", style="magenta")
        table.add_column("Index", style="cyan")
        table.add_column("Version Files", style="green")
        table.add_column("Issues Fetched", style="yellow")
        table.add_column("Cache Hits", style="dim yellow")

        issues_fetched = str(fetcher.fetch_count) if fetcher else "—"
        cache_hits = str(fetcher.cache_hit_count) if fetcher else "—"

        table.add_row(
            DARTCODE_OUTPUT_DIR,
            EXTRACT_FILE,
            str(file_count),
            issues_fetched,
            cache_hits,
        )
        console.print("\n", table)
        console.print(f"\n[bold green]Dart-Code done![/bold green] {file_count} version files.")


class FlutterSdkScraper:
    """Scrapes Flutter SDK release notes from docs.flutter.dev."""

    def __init__(self, min_version: str = "3.0.0", fetch_prs: bool = False):
        self.min_version_str = min_version
        self.min_version_tuple = self._parse_version(min_version)
        self.session = requests.Session()
        self.fetch_prs = fetch_prs

    def _parse_version(self, v: str) -> Tuple[int, ...]:
        nums = re.findall(r'\d+', v)
        return tuple(int(n) for n in nums)

    def fetch_version_links(self) -> List[Tuple[str, str]]:
        """Scrapes the release notes index page for version URLs."""
        logging.info("Requesting Flutter SDK release notes index...")
        try:
            response = self.session.get(f"{FLUTTER_BASE_URL}/release/release-notes")
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'html.parser')

            versions = []
            seen = set()

            for a in soup.find_all('a', href=True):
                href = a['href']
                match = re.search(r'release-notes-(\d+\.\d+\.\d+)', href)
                if match:
                    v_str = match.group(1)
                    if v_str not in seen:
                        seen.add(v_str)
                        url = f"{FLUTTER_BASE_URL}/release/release-notes/release-notes-{v_str}"
                        versions.append((v_str, url))

            versions.sort(key=lambda x: self._parse_version(x[0]), reverse=True)
            return versions
        except Exception as e:
            console.print(f"[bold red]Error fetching Flutter version list:[/bold red] {e}")
            logging.error(f"Failed to fetch Flutter version list: {e}")
            return []

    def html_to_markdown(self, html_content: str) -> str:
        """Converts Flutter release notes HTML to markdown."""
        soup = BeautifulSoup(html_content, 'html.parser')

        content = (
            soup.find('main')
            or soup.find('article')
            or soup.find('div', class_='site-content')
            or soup.body
        )

        if content == soup.body:
            for tag in soup.find_all(['nav', 'header', 'footer']):
                tag.decompose()

        h = html2text.HTML2Text()
        h.ignore_links = False
        h.body_width = 0

        md_text = h.handle(str(content))

        # Strip nav boilerplate — start from "This page has release notes"
        match = re.search(r'^This page has release notes', md_text, re.MULTILINE)
        if match:
            md_text = md_text[match.start():]

        return md_text.strip()

    def run(self):
        mode_label = "with PR details" if self.fetch_prs else "release notes only"
        intro_text = (
            f"[bold magenta]Flutter SDK Release Scraper[/bold magenta] ({mode_label})\n"
            f"Targeting: [green]{self.min_version_str}[/green] and newer"
        )
        console.print(Panel(intro_text, expand=False), justify="center")

        all_versions = self.fetch_version_links()
        target_versions = []

        for v_str, url in all_versions:
            v_tuple = self._parse_version(v_str)
            if v_tuple < self.min_version_tuple:
                break
            target_versions.append((v_str, url))

        if not target_versions:
            console.print("[yellow]No Flutter versions found matching your criteria.[/yellow]")
            return

        # --- Phase 1: Scrape docs.flutter.dev ---
        version_content: Dict[str, str] = {}

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=console,
        ) as progress:
            task = progress.add_task(
                "[magenta]Scraping docs.flutter.dev...",
                total=len(target_versions),
            )

            for v_str, url in target_versions:
                progress.update(task, description=f"[magenta]Scraping Flutter {v_str}...")
                try:
                    res = self.session.get(url)
                    res.raise_for_status()
                    version_content[v_str] = self.html_to_markdown(res.text)
                    logging.info(f"Scraped Flutter {v_str}")
                except Exception as e:
                    logging.error(f"Error scraping Flutter {v_str}: {e}")
                    version_content[v_str] = "> [!ERROR] Failed to fetch content."
                progress.advance(task)

        # --- Phase 2: Optionally fetch PR details ---
        fetcher = None
        if self.fetch_prs:
            cache_path = os.path.join(FLUTTER_OUTPUT_DIR, "pr_cache.json")
            fetcher = IssueFetcher(FLUTTER_REPO, cache_path)

            if not fetcher.gh_available:
                console.print("[yellow]gh CLI not authenticated — skipping PR details.[/yellow]")
                fetcher = None
            else:
                all_pr_nums: Set[str] = set()
                for content in version_content.values():
                    all_pr_nums.update(extract_issue_numbers(content, FLUTTER_REPO))

                uncached = [n for n in all_pr_nums if n not in fetcher.cache]
                cached_count = len(all_pr_nums) - len(uncached)

                console.print(
                    f"\n[dim]PRs: {len(all_pr_nums)} total, "
                    f"{cached_count} cached, {len(uncached)} to fetch[/dim]"
                )

                if uncached:
                    with Progress(
                        SpinnerColumn(),
                        TextColumn("[progress.description]{task.description}"),
                        BarColumn(),
                        TaskProgressColumn(),
                        console=console,
                    ) as progress:
                        task = progress.add_task(
                            "[green]Fetching Flutter PRs...",
                            total=len(uncached),
                        )
                        fetcher.fetch_batch(uncached, progress, task)

                    console.print(
                        f"[dim]Fetched {fetcher.fetch_count} PRs, "
                        f"cache saved to pr_cache.json[/dim]"
                    )

        # --- Phase 3: Write per-version files + index ---
        os.makedirs(FLUTTER_OUTPUT_DIR, exist_ok=True)
        versions_dir = os.path.join(FLUTTER_OUTPUT_DIR, "versions")
        os.makedirs(versions_dir, exist_ok=True)

        version_files = []
        for v_str, _ in target_versions:
            content = version_content.get(v_str, "")
            pr_count = len(extract_issue_numbers(content, FLUTTER_REPO))
            if fetcher:
                content = enrich_feature_text(content, fetcher)

            filename = f"flutter-{v_str}.md"
            filepath = os.path.join(versions_dir, filename)
            with open(filepath, "w", encoding="utf-8") as vf:
                vf.write(f"# Flutter SDK {v_str}\n\n")
                vf.write(content)
                vf.write("\n")

            version_files.append((v_str, filename, pr_count))

        # Write index file
        index_path = os.path.join(FLUTTER_OUTPUT_DIR, EXTRACT_FILE)
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(index_path, "w", encoding="utf-8") as idx:
            idx.write("# Flutter SDK Release Notes Archive\n\n")
            idx.write(f"Generated on: {timestamp}\n")
            idx.write(f"Version Range: {target_versions[0][0]} down to {target_versions[-1][0]}\n")
            if fetcher:
                idx.write("Includes: GitHub PR details (expanded inline)\n")
            idx.write("\n---\n\n")
            idx.write("| Version | PRs | File |\n")
            idx.write("|---------|-----|------|\n")
            for v_str, filename, pr_count in version_files:
                idx.write(f"| {v_str} | {pr_count} | [versions/{filename}](versions/{filename}) |\n")

        self._display_summary(target_versions, fetcher, len(version_files))

    def _display_summary(self, processed_versions, fetcher: Optional[IssueFetcher], file_count: int):
        table = Table(title="Flutter SDK Extraction Summary")
        table.add_column("Output Folder", style="magenta")
        table.add_column("Index", style="cyan")
        table.add_column("Version Files", style="green")
        table.add_column("PRs Fetched", style="yellow")
        table.add_column("Cache Hits", style="dim yellow")

        prs_fetched = str(fetcher.fetch_count) if fetcher else "—"
        cache_hits = str(fetcher.cache_hit_count) if fetcher else "—"

        table.add_row(
            FLUTTER_OUTPUT_DIR,
            EXTRACT_FILE,
            str(file_count),
            prs_fetched,
            cache_hits,
        )
        console.print("\n", table)
        console.print(f"\n[bold green]Flutter SDK done![/bold green] {file_count} version files.")


class DartSdkScraper:
    """Downloads and splits the Dart SDK CHANGELOG.md by version."""

    def __init__(self, min_version: str = "3.0.0"):
        self.min_version_str = min_version
        self.min_version_tuple = self._parse_version(min_version)

    def _parse_version(self, v: str) -> Tuple[int, ...]:
        nums = re.findall(r'\d+', v)
        return tuple(int(n) for n in nums)

    def run(self):
        intro_text = (
            f"[bold yellow]Dart SDK Changelog Scraper[/bold yellow]\n"
            f"Targeting: [green]{self.min_version_str}[/green] and newer"
        )
        console.print(Panel(intro_text, expand=False), justify="center")

        # Download CHANGELOG.md
        console.print("[yellow]Downloading Dart SDK CHANGELOG.md...[/yellow]")
        try:
            response = requests.get(DART_SDK_CHANGELOG_URL)
            response.raise_for_status()
            changelog = response.text
        except Exception as e:
            console.print(f"[bold red]Failed to download:[/bold red] {e}")
            return

        # Split into version sections
        sections = re.split(r'^(## \d+\.\d+\.\d+)', changelog, flags=re.MULTILINE)

        versions: Dict[str, str] = {}
        i = 1
        while i < len(sections) - 1:
            header = sections[i].strip()
            body = sections[i + 1].strip()
            match = re.search(r'(\d+\.\d+\.\d+)', header)
            if match:
                v_str = match.group(1)
                v_tuple = self._parse_version(v_str)
                if v_tuple >= self.min_version_tuple:
                    versions[v_str] = f"{header}\n\n{body}"
            i += 2

        if not versions:
            console.print("[yellow]No Dart SDK versions found matching criteria.[/yellow]")
            return

        # Sort descending
        sorted_versions = sorted(
            versions.keys(),
            key=lambda v: self._parse_version(v),
            reverse=True,
        )

        # Write per-version files
        os.makedirs(DART_SDK_OUTPUT_DIR, exist_ok=True)
        versions_dir = os.path.join(DART_SDK_OUTPUT_DIR, "versions")
        os.makedirs(versions_dir, exist_ok=True)

        version_files = []
        for v_str in sorted_versions:
            filename = f"dart-{v_str}.md"
            filepath = os.path.join(versions_dir, filename)
            content = versions[v_str]
            line_count = len(content.split('\n'))

            with open(filepath, "w", encoding="utf-8") as vf:
                vf.write(f"# Dart SDK {v_str}\n\n")
                vf.write(content)
                vf.write("\n")

            version_files.append((v_str, filename, line_count))

        # Write index
        index_path = os.path.join(DART_SDK_OUTPUT_DIR, EXTRACT_FILE)
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(index_path, "w", encoding="utf-8") as idx:
            idx.write("# Dart SDK Changelog Archive\n\n")
            idx.write(f"Generated on: {timestamp}\n")
            idx.write(f"Version Range: {sorted_versions[0]} down to {sorted_versions[-1]}\n")
            idx.write("\n---\n\n")
            idx.write("| Version | Lines | File |\n")
            idx.write("|---------|-------|------|\n")
            for v_str, filename, line_count in version_files:
                idx.write(f"| {v_str} | {line_count} | [versions/{filename}](versions/{filename}) |\n")

        table = Table(title="Dart SDK Extraction Summary")
        table.add_column("Output Folder", style="magenta")
        table.add_column("Version Files", style="green")
        table.add_row(DART_SDK_OUTPUT_DIR, str(len(version_files)))
        console.print("\n", table)
        console.print(f"\n[bold green]Dart SDK done![/bold green] {len(version_files)} version files.")


if __name__ == "__main__":
    # Dart-Code VS Code extension
    dart_code = DartCodeScraper(start_version="v3-50", fetch_issues=True)
    dart_code.run()

    console.print("\n" + "=" * 60 + "\n")

    # Flutter SDK
    flutter_sdk = FlutterSdkScraper(min_version="3.0.0", fetch_prs=False)
    flutter_sdk.run()

    console.print("\n" + "=" * 60 + "\n")

    # Dart SDK
    dart_sdk = DartSdkScraper(min_version="3.0.0")
    dart_sdk.run()
