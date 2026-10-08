# grape-oas website

Source for the [grape-oas website](https://numbata.github.io/grape-oas/), its getting-started guide, and reproducible release benchmarks. Tracked in [issue #170](https://github.com/numbata/grape-oas/issues/170).

This is an independent branch, not a second copy of the gem. Do not merge it into `main`. The gem's source and reference docs stay on `main`; generated website files are published on `gh-pages`.

## Setup

Use Ruby 3.2 or newer, selected with your Ruby version manager. The initial reports use Ruby 3.3.6. Then run:

```sh
bundle install
```

`Gemfile.lock` pins benchmark dependencies. The harness loads the target gem's `lib/` from an extracted Git commit, so dependencies stay fixed while grape-oas changes. This branch has no gemspec and adds no dependencies to the published gem.

## Run benchmarks

Keep the gem repository in a sibling directory named `grape-oas`, or supply `--repo`:

```sh
git -C ../grape-oas fetch origin
bundle exec ruby benchmark/run.rb --repo ../grape-oas
ruby site/build.rb
```

Defaults: latest patch release in each existing minor from 1.0 through 1.6, plus the exact `origin/main` commit; 100, 500, and 1,000 routes; OAS 2.0, 3.0, and 3.1; one warmup and ten measured generations. Each target runs in a separate process with JIT disabled. Timing excludes API setup and JSON serialization; garbage collection stays enabled.

For a quick diagnostic, keep output outside `results/` so it is not published:

```sh
bundle exec ruby benchmark/run.rb --refs v1.6.0,origin/main --routes 3 --iterations 2 --output build/smoke
```

Do not interpret this synthetic route-count workload as HTTP throughput or entity/contract performance. Negative percentage changes mean faster generation. Compare only matching environments, lockfiles, and harness revisions. Rerun releases after any of those change. Failed cases are shown explicitly and do not produce comparisons.

Each case has a 30-second budget for warmup plus measured generations. Timeouts are reported as failures, with no partial timings or percentage comparisons. Use `--case-timeout N` for longer runs. This bound prevents pathological historical cases from blocking a report.

The runner records SHA references, harness revision and digest, samples, lockfile digest, exact dependencies, Ruby, OS, CPU, and methodology. It resolves refs before extraction and never checks out or edits the gem repository. Local paths and hostnames are not included in public reports. Commit harness changes before recording a published run.

## Build and preview

```sh
ruby site/build.rb
ruby -run -e httpd build -p 8080
```

Open <http://localhost:8080/grape-oas/>. The build generates HTML, CSS, archived JSON, and Markdown in `build/grape-oas/`. It needs only Ruby's standard library and does not run benchmarks. `site.json` sets the project URL prefix, documented release, and repository links.

The homepage and guide share `examples/api.rb`. To change the documented release, update `site.json` and validate that example against its release checkout. Reference links target current GitHub docs and are labeled accordingly. No tracking, external fonts, or JavaScript is loaded.

## Verify

```sh
bundle exec ruby test/report_test.rb
```

Validate the guide against an extracted stable release:

```sh
mkdir -p build/release
git -C ../grape-oas archive v1.6.0 | tar -x -C build/release
bundle exec ruby -I build/release/lib test/example_test.rb
```

Check the generated pages at desktop and mobile widths, keyboard focus, code/table scrolling, download links, and project-prefixed URLs before publishing. Inspect report failures and small or unexpected differences before making claims.

## Publish manually

The `gh-pages` branch contains generated files only. Configure GitHub Settings → Pages → Deploy from a branch → `gh-pages` → `/ (root)`.

Create its worktree once, after the branch exists:

```sh
git worktree add ../grape-oas-pages gh-pages
```

For each update:

```sh
ruby site/build.rb
cp -R build/grape-oas/. ../grape-oas-pages/
git -C ../grape-oas-pages add index.html getting-started/index.html benchmarks assets .nojekyll
git -C ../grape-oas-pages diff --cached --stat
git -C ../grape-oas-pages commit -m "Update grape-oas website"
git -C ../grape-oas-pages push origin gh-pages
```

Stage source changes by specific filenames and push `website` separately. Do not force-push. If an asset or archive is intentionally removed, remove it explicitly from the publishing worktree too. Revert the publishing commit to roll back. No custom GitHub workflow or changes to the gem's release pipeline are required.
