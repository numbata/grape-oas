# frozen_string_literal: true

require "bundler/setup"
require "grape"
require "grape-entity"
require "dry-schema"
require "dry-validation"
require "grape_oas"
require "memory_profiler"
require "json"

# Complex nested entities for realistic memory profiling
module BenchmarkEntities
  class AddressEntity < Grape::Entity
    expose :street, documentation: { type: String, desc: "Street address" }
    expose :city, documentation: { type: String, desc: "City name" }
    expose :country, documentation: { type: String, desc: "Country code" }
    expose :postal_code, documentation: { type: String, desc: "Postal/ZIP code" }
  end

  class CompanyEntity < Grape::Entity
    expose :name, documentation: { type: String, desc: "Company name" }
    expose :industry, documentation: { type: String, desc: "Industry sector" }
    expose :address, using: AddressEntity, documentation: { type: AddressEntity, desc: "Company HQ" }
  end

  class ProfileEntity < Grape::Entity
    expose :bio, documentation: { type: String, desc: "User biography" }
    expose :avatar_url, documentation: { type: String, desc: "Avatar URL" }
    expose :social_links, documentation: { type: Hash, desc: "Social media links" }
  end

  class UserEntity < Grape::Entity
    expose :id, documentation: { type: Integer, desc: "User ID" }
    expose :email, documentation: { type: String, desc: "Email address" }
    expose :name, documentation: { type: String, desc: "Full name" }
    expose :profile, using: ProfileEntity, documentation: { type: ProfileEntity }
    expose :company, using: CompanyEntity, documentation: { type: CompanyEntity }
    expose :addresses, using: AddressEntity, documentation: { type: AddressEntity, is_array: true }
  end

  class CommentEntity < Grape::Entity
    expose :id, documentation: { type: Integer }
    expose :body, documentation: { type: String }
    expose :author, using: UserEntity, documentation: { type: UserEntity }
    expose :created_at, documentation: { type: DateTime }
  end

  class TagEntity < Grape::Entity
    expose :name, documentation: { type: String }
    expose :color, documentation: { type: String }
  end

  class ArticleEntity < Grape::Entity
    expose :id, documentation: { type: Integer, desc: "Article ID" }
    expose :title, documentation: { type: String, desc: "Article title" }
    expose :body, documentation: { type: String, desc: "Article content" }
    expose :author, using: UserEntity, documentation: { type: UserEntity }
    expose :comments, using: CommentEntity, documentation: { type: CommentEntity, is_array: true }
    expose :tags, using: TagEntity, documentation: { type: TagEntity, is_array: true }
    expose :published_at, documentation: { type: DateTime }
  end

  # Deep nesting: Organization -> Teams -> Members -> Projects
  class ProjectEntity < Grape::Entity
    expose :name, documentation: { type: String }
    expose :status, documentation: { type: String }
  end

  class TeamMemberEntity < Grape::Entity
    expose :user, using: UserEntity, documentation: { type: UserEntity }
    expose :role, documentation: { type: String }
    expose :projects, using: ProjectEntity, documentation: { type: ProjectEntity, is_array: true }
  end

  class TeamEntity < Grape::Entity
    expose :name, documentation: { type: String }
    expose :members, using: TeamMemberEntity, documentation: { type: TeamMemberEntity, is_array: true }
  end

  class OrganizationEntity < Grape::Entity
    expose :id, documentation: { type: Integer }
    expose :name, documentation: { type: String }
    expose :address, using: AddressEntity, documentation: { type: AddressEntity }
    expose :teams, using: TeamEntity, documentation: { type: TeamEntity, is_array: true }
  end
end

# Dry contracts for request validation
module BenchmarkContracts
  CreateUserContract = Dry::Schema.Params do
    required(:email).filled(:string, format?: URI::MailTo::EMAIL_REGEXP)
    required(:name).filled(:string, min_size?: 2, max_size?: 100)
    optional(:bio).maybe(:string, max_size?: 500)

    required(:address).hash do
      required(:street).filled(:string)
      required(:city).filled(:string)
      required(:country).filled(:string, size?: 2)
      optional(:postal_code).maybe(:string)
    end
  end

  UpdateArticleContract = Dry::Schema.Params do
    optional(:title).filled(:string, min_size?: 5, max_size?: 200)
    optional(:body).filled(:string, min_size?: 100)
    optional(:status).filled(:string, included_in?: %w[draft review published archived])

    optional(:tags).array(:hash) do
      required(:name).filled(:string)
      optional(:color).filled(:string, format?: /^#[0-9A-Fa-f]{6}$/)
    end
  end

  SearchContract = Dry::Schema.Params do
    optional(:q).filled(:string, min_size?: 2)
    optional(:page).filled(:integer, gteq?: 1)
    optional(:per_page).filled(:integer, gteq?: 1, lteq?: 100)
    optional(:sort_by).filled(:string, included_in?: %w[created_at updated_at name relevance])
    optional(:order).filled(:string, included_in?: %w[asc desc])

    optional(:filters).hash do
      optional(:status).array(:string)
      optional(:tags).array(:string)
      optional(:author_id).filled(:integer)
      optional(:date_from).filled(:date)
      optional(:date_to).filled(:date)
    end
  end

  CreateOrganizationContract = Dry::Validation.Contract do
    params do
      required(:name).filled(:string, min_size?: 2)
      required(:industry).filled(:string)

      required(:address).hash do
        required(:street).filled(:string)
        required(:city).filled(:string)
        required(:country).filled(:string, size?: 2)
      end

      optional(:teams).array(:hash) do
        required(:name).filled(:string)
        optional(:members).array(:hash) do
          required(:user_id).filled(:integer)
          required(:role).filled(:string, included_in?: %w[admin member viewer])
        end
      end
    end

    rule(:teams) do
      value&.each_with_index do |team, idx|
        key([:teams, idx, :name]).failure("must be unique") if value.count { |t| t[:name] == team[:name] } > 1
      end
    end
  end
end

# Complex API with multiple namespaces and endpoints
class BenchmarkAPI < Grape::API
  format :json
  prefix :api
  version "v1", using: :path

  helpers do
    params :pagination do
      optional :page, type: Integer, default: 1
      optional :per_page, type: Integer, default: 20
    end
  end

  namespace :users do
    desc "List users", entity: BenchmarkEntities::UserEntity
    params do
      optional :page, type: Integer
      optional :per_page, type: Integer
    end
    get { [] }

    desc "Create user", contract: BenchmarkContracts::CreateUserContract, entity: BenchmarkEntities::UserEntity
    post { {} }

    route_param :id, type: Integer do
      desc "Get user", entity: BenchmarkEntities::UserEntity
      get { {} }

      desc "Update user", contract: BenchmarkContracts::CreateUserContract, entity: BenchmarkEntities::UserEntity
      put { {} }

      desc "Delete user"
      delete { {} }
    end
  end

  namespace :articles do
    desc "List articles", entity: BenchmarkEntities::ArticleEntity
    params do
      use :pagination
    end
    get { [] }

    desc "Search articles", contract: BenchmarkContracts::SearchContract, entity: BenchmarkEntities::ArticleEntity
    get :search do
      []
    end

    desc "Create article", entity: BenchmarkEntities::ArticleEntity
    params do
      requires :title, type: String
      requires :body, type: String
      optional :tags, type: [String]
    end
    post { {} }

    route_param :id, type: Integer do
      desc "Get article", entity: BenchmarkEntities::ArticleEntity
      get { {} }

      desc "Update article", contract: BenchmarkContracts::UpdateArticleContract, entity: BenchmarkEntities::ArticleEntity
      put { {} }

      namespace :comments do
        desc "List comments", entity: BenchmarkEntities::CommentEntity
        get { [] }

        desc "Add comment", entity: BenchmarkEntities::CommentEntity
        params do
          requires :body, type: String
        end
        post { {} }
      end
    end
  end

  namespace :organizations do
    desc "List organizations", entity: BenchmarkEntities::OrganizationEntity
    get { [] }

    desc "Create organization",
         contract: BenchmarkContracts::CreateOrganizationContract,
         entity: BenchmarkEntities::OrganizationEntity
    post { {} }

    route_param :id, type: Integer do
      desc "Get organization", entity: BenchmarkEntities::OrganizationEntity
      get { {} }

      namespace :teams do
        desc "List teams", entity: BenchmarkEntities::TeamEntity
        get { [] }

        route_param :team_id, type: Integer do
          desc "Get team", entity: BenchmarkEntities::TeamEntity
          get { {} }

          namespace :members do
            desc "List members", entity: BenchmarkEntities::TeamMemberEntity
            get { [] }
          end
        end
      end
    end
  end
end

class MemoryBenchmark
  ITERATIONS = Integer(ENV.fetch("ITERATIONS", 5))
  TOP_ALLOCATIONS = Integer(ENV.fetch("TOP_ALLOCATIONS", 10))
  GEM_PATH = File.expand_path("..", __dir__)

  def initialize(output: $stdout, format: :text)
    @output = output
    @format = format
    @results = []
  end

  def run
    log_header
    warm_up
    run_iterations
    analyze_results
  end

  def report
    case @format
    when :json
      JSON.pretty_generate(build_json_report)
    when :markdown
      build_markdown_report
    else
      build_text_report
    end
  end

  private

  def log_header
    return unless @format == :text

    @output.puts "=" * 60
    @output.puts "Memory Profile: grape-oas OAS Generation"
    @output.puts "=" * 60
    @output.puts "Iterations: #{ITERATIONS}"
    @output.puts "API endpoints: #{BenchmarkAPI.routes.size}"
    @output.puts ""
  end

  def warm_up
    log "Warming up..." if @format == :text
    GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas3)
    GC.start(full_mark: true, immediate_sweep: true)
    log "Warm-up complete\n" if @format == :text
  end

  def run_iterations
    ITERATIONS.times do |i|
      GC.start(full_mark: true, immediate_sweep: true)
      before_mem = current_memory

      report = MemoryProfiler.report(top: TOP_ALLOCATIONS) do
        GrapeOAS.generate(app: BenchmarkAPI, schema_type: :oas3)
      end

      after_mem = current_memory

      @results << {
        iteration: i + 1,
        allocated_memory: report.total_allocated_memsize,
        retained_memory: report.total_retained_memsize,
        allocated_objects: report.total_allocated,
        retained_objects: report.total_retained,
        process_memory_delta: after_mem - before_mem,
        top_allocated: extract_top_locations(report.allocated_memory_by_location),
        top_retained: extract_top_locations(report.retained_memory_by_location)
      }

      log_iteration(i + 1) if @format == :text
    end
  end

  def extract_top_locations(locations)
    # Filter to only grape-oas files
    gem_locations = locations.select { |loc| loc[:data].start_with?(GEM_PATH) }

    gem_locations.first(TOP_ALLOCATIONS).map do |loc|
      {
        location: loc[:data].sub("#{GEM_PATH}/", ""),
        memory: loc[:count]
      }
    end
  end

  def current_memory
    `ps -o rss= -p #{Process.pid}`.to_i * 1024
  end

  def log_iteration(num)
    result = @results.last
    @output.puts "Iteration #{num}:"
    @output.puts "  Allocated: #{format_bytes(result[:allocated_memory])} (#{result[:allocated_objects]} objects)"
    @output.puts "  Retained:  #{format_bytes(result[:retained_memory])} (#{result[:retained_objects]} objects)"
    @output.puts ""
  end

  def analyze_results
    return if @results.empty?

    @analysis = {
      avg_allocated: @results.sum { |r| r[:allocated_memory] } / @results.size,
      avg_retained: @results.sum { |r| r[:retained_memory] } / @results.size,
      retained_trend: calculate_trend(:retained_memory),
      memory_stable: memory_stable?,
      potential_leak: potential_leak?
    }
  end

  def calculate_trend(key)
    return 0 if @results.size < 2

    first_half = @results[0...(@results.size / 2)]
    second_half = @results[(@results.size / 2)..]

    first_avg = first_half.sum { |r| r[key] }.to_f / first_half.size
    second_avg = second_half.sum { |r| r[key] }.to_f / second_half.size

    ((second_avg - first_avg) / first_avg * 100).round(2)
  end

  def memory_stable?
    return true if @results.size < 2

    retained_values = @results.map { |r| r[:retained_memory] }
    variance = calculate_variance(retained_values)
    mean = retained_values.sum.to_f / retained_values.size

    # Coefficient of variation < 10% is considered stable
    (Math.sqrt(variance) / mean * 100) < 10
  end

  def potential_leak?
    return false if @results.size < 3

    # Check if retained memory is consistently growing
    retained = @results.map { |r| r[:retained_memory] }
    growing_count = retained.each_cons(2).count { |a, b| b > a }

    growing_count >= (@results.size - 1) * 0.7
  end

  def calculate_variance(values)
    mean = values.sum.to_f / values.size
    values.sum { |v| (v - mean)**2 } / values.size
  end

  def build_json_report
    {
      summary: {
        iterations: ITERATIONS,
        endpoints: BenchmarkAPI.routes.size,
        avg_allocated_bytes: @analysis[:avg_allocated],
        avg_retained_bytes: @analysis[:avg_retained],
        retained_trend_percent: @analysis[:retained_trend],
        memory_stable: @analysis[:memory_stable],
        potential_leak: @analysis[:potential_leak]
      },
      iterations: @results
    }
  end

  def build_markdown_report
    <<~MARKDOWN
      ## Memory Profile Report

      ### Summary
      | Metric | Value |
      |--------|-------|
      | Iterations | #{ITERATIONS} |
      | API Endpoints | #{BenchmarkAPI.routes.size} |
      | Avg Allocated | #{format_bytes(@analysis[:avg_allocated])} |
      | Avg Retained | #{format_bytes(@analysis[:avg_retained])} |
      | Retained Trend | #{@analysis[:retained_trend]}% |
      | Memory Stable | #{@analysis[:memory_stable] ? "Yes" : "No"} |
      | Potential Leak | #{@analysis[:potential_leak] ? "**Yes**" : "No"} |

      ### Iteration Details
      | # | Allocated | Retained | Objects |
      |---|-----------|----------|---------|
      #{@results.map { |r| "| #{r[:iteration]} | #{format_bytes(r[:allocated_memory])} | #{format_bytes(r[:retained_memory])} | #{r[:allocated_objects]} |" }.join("\n")}

      ### Top Memory Allocations (by location)
      #{top_allocations_table}

      #{leak_warning if @analysis[:potential_leak]}
    MARKDOWN
  end

  def top_allocations_table
    # Aggregate across all iterations
    aggregated = Hash.new(0)
    @results.each do |r|
      r[:top_allocated].each do |loc|
        aggregated[loc[:location]] += loc[:memory]
      end
    end

    sorted = aggregated.sort_by { |_, v| -v }.first(TOP_ALLOCATIONS)

    rows = sorted.map.with_index do |(location, memory), idx|
      "| #{idx + 1} | #{format_bytes(memory / ITERATIONS)} | `#{truncate_location(location)}` |"
    end

    <<~TABLE
      | # | Avg Memory | Location |
      |---|------------|----------|
      #{rows.join("\n")}
    TABLE
  end

  def leak_warning
    <<~WARNING

      > **Warning**: Potential memory leak detected. Retained memory is consistently growing across iterations.
      > Consider investigating the top retained allocations.
    WARNING
  end

  def build_text_report
    lines = []
    lines << ("=" * 60)
    lines << "Analysis Results"
    lines << ("=" * 60)
    lines << "Average allocated: #{format_bytes(@analysis[:avg_allocated])}"
    lines << "Average retained:  #{format_bytes(@analysis[:avg_retained])}"
    lines << "Retained trend:    #{@analysis[:retained_trend]}%"
    lines << "Memory stable:     #{@analysis[:memory_stable]}"
    lines << "Potential leak:    #{@analysis[:potential_leak]}"
    lines << ""
    lines << "Top #{TOP_ALLOCATIONS} memory allocations by location:"
    lines << ("-" * 60)

    aggregated = Hash.new(0)
    @results.each do |r|
      r[:top_allocated].each { |loc| aggregated[loc[:location]] += loc[:memory] }
    end

    aggregated.sort_by { |_, v| -v }.first(TOP_ALLOCATIONS).each_with_index do |(location, memory), idx|
      lines << "#{idx + 1}. #{format_bytes(memory / ITERATIONS)} - #{location}"
    end

    lines.join("\n")
  end

  def format_bytes(bytes)
    return "0 B" if bytes.zero?

    units = %w[B KB MB GB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = [exp, units.size - 1].min

    format("%<value>.2f %<unit>s", value: bytes.to_f / (1024**exp), unit: units[exp])
  end

  def truncate_location(location)
    return location if location.length <= 80

    "...#{location[-77..]}"
  end

  def log(msg)
    @output.puts msg
  end
end

if __FILE__ == $PROGRAM_NAME
  format = case ARGV[0]
           when "--json" then :json
           when "--markdown", "--md" then :markdown
           else :text
           end

  benchmark = MemoryBenchmark.new(format: format)
  benchmark.run
  puts benchmark.report
end
