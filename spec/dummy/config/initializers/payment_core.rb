PaymentCore.setup do |config|

#   config.configure_events do |event|
#     event.subscribe 'invoice.after_save' do |invoice|
#       invoice
#     end
#   end

   config.grape_api.setup do |api|
    api.authenticate! do
      User.first
    end
#     api.authorize! do |*args|
#       override authorize here
#     end

#     api.draw_callbacks do
#       endpoint :products do
#         callback :set_presenter, "Presenters::PosProduct"
#         callback :should_paginate?, true
#         callback :query_scope do |query|
#           query
#         end
#         callback :query_includes do
#           [:user]
#         end
#         callback :after_fetch_resource do |record|
#           record
#         end
#         callback :model_klass do
#           "Pos::Product"
#         end
#         callback :resource_identifier do
#           :id
#         end
#         callback :resource_finder_key do
#           :id
#         end
#         callback :resource_actions do
#           [ :show, :new, :create, :edit, :update, :destroy ]
#         end
#         callback :resources_actions do
#           [:index]
#         end
#         callback :before do
#           #here
#         end
#         callback :before_validation do
#           #here
#         end
#         callback :after_validation do
#           #here
#         end
#         callback :after do
#           #here
#         end
#       end
#     end
#     api.pagination.configure do |pagination|
#       pagination.per_page_count= 1
#       pagination.total= "Total"
#       pagination.per_page= "Per-Page"
#       pagination.page= nil
#       pagination.total_page= "Total-Pages"
#       pagination.last_page= "Last-Page"
#       pagination.base_url= nil
#       pagination.include_total=true
#       paginator=:pagy
#     end
  end

end