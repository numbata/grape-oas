# frozen_string_literal: true

# benchmark/support/test_api.rb
# Shared test API for all benchmarks
#
# This provides realistic Grape API definitions with:
# - Complex nested entities (grape-entity)
# - Request validation contracts (dry-schema, dry-validation)
# - Multiple namespaces and nested routes

require "bundler/setup"
require "grape"
require "grape-entity"
require "dry-schema"
require "dry-validation"
require "grape_oas"

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

# Complex API with multiple namespaces and endpoints (~25 routes)
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

# Simpler API for quick benchmarks
class SimpleAPI < Grape::API
  format :json
  prefix :api

  namespace :items do
    desc "List items"
    params do
      optional :page, type: Integer
    end
    get do
      []
    end

    desc "Get item"
    params do
      requires :id, type: Integer
    end
    get ":id" do
      {}
    end

    desc "Create item"
    params do
      requires :name, type: String
    end
    post do
      {}
    end
  end
end
