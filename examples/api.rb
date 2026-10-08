# frozen_string_literal: true

require "grape_oas"

class CatalogAPI < Grape::API
  format :json

  desc "Find a book"
  params do
    requires :id, type: Integer, desc: "Book ID"
  end
  get "books/:id" do
    { id: params[:id], title: "The Ruby Programming Language" }
  end

  add_oas_documentation(
    info: { title: "Catalog API", version: "1.0.0" },
  )
end
