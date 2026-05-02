# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  if ENV.fetch("MISSION_CONTROL", "0") == "1"
    # Monitor and manage background jobs and scheduled tasks
    mount MissionControl::Jobs::Engine, at: "/background_jobs"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"

  devise_for :users, controllers: {
    registrations: "registrations",
  }

  resources :configurations, only: [:index, :update]

  resources :servers do
    collection do
      post :test
    end

    member do
      post :measure
    end
  end

  resources :repositories

  resources :notifications do
    collection do
      post :test
    end

    member do
      post :test
    end
  end

  resources :jobs, except: :show do
    collection do
      post :preview
    end
  end

  resources :job_runs, only: [:index, :show, :create, :destroy] do
    member do
      patch :cancel
      get :logs
    end
  end
end

# == Route Map
#
#                                   Prefix Verb   URI Pattern                                                                                       Controller#Action
#                       rails_health_check GET    /up(.:format)                                                                                     rails/health#show
#                                     root GET    /                                                                                                 dashboard#index
#                         new_user_session GET    /users/sign_in(.:format)                                                                          devise/sessions#new
#                             user_session POST   /users/sign_in(.:format)                                                                          devise/sessions#create
#                     destroy_user_session DELETE /users/sign_out(.:format)                                                                         devise/sessions#destroy
#                 cancel_user_registration GET    /users/cancel(.:format)                                                                           registrations#cancel
#                    new_user_registration GET    /users/sign_up(.:format)                                                                          registrations#new
#                   edit_user_registration GET    /users/edit(.:format)                                                                             registrations#edit
#                        user_registration PATCH  /users(.:format)                                                                                  registrations#update
#                                          PUT    /users(.:format)                                                                                  registrations#update
#                                          DELETE /users(.:format)                                                                                  registrations#destroy
#                                          POST   /users(.:format)                                                                                  registrations#create
#                           configurations GET    /configurations(.:format)                                                                         configurations#index
#                            configuration PATCH  /configurations/:id(.:format)                                                                     configurations#update
#                                          PUT    /configurations/:id(.:format)                                                                     configurations#update
#                             test_servers POST   /servers/test(.:format)                                                                           servers#test
#                           measure_server POST   /servers/:id/measure(.:format)                                                                    servers#measure
#                                  servers GET    /servers(.:format)                                                                                servers#index
#                                          POST   /servers(.:format)                                                                                servers#create
#                               new_server GET    /servers/new(.:format)                                                                            servers#new
#                              edit_server GET    /servers/:id/edit(.:format)                                                                       servers#edit
#                                   server GET    /servers/:id(.:format)                                                                            servers#show
#                                          PATCH  /servers/:id(.:format)                                                                            servers#update
#                                          PUT    /servers/:id(.:format)                                                                            servers#update
#                                          DELETE /servers/:id(.:format)                                                                            servers#destroy
#                             repositories GET    /repositories(.:format)                                                                           repositories#index
#                                          POST   /repositories(.:format)                                                                           repositories#create
#                           new_repository GET    /repositories/new(.:format)                                                                       repositories#new
#                          edit_repository GET    /repositories/:id/edit(.:format)                                                                  repositories#edit
#                               repository GET    /repositories/:id(.:format)                                                                       repositories#show
#                                          PATCH  /repositories/:id(.:format)                                                                       repositories#update
#                                          PUT    /repositories/:id(.:format)                                                                       repositories#update
#                                          DELETE /repositories/:id(.:format)                                                                       repositories#destroy
#                       test_notifications POST   /notifications/test(.:format)                                                                     notifications#test
#                        test_notification POST   /notifications/:id/test(.:format)                                                                 notifications#test
#                            notifications GET    /notifications(.:format)                                                                          notifications#index
#                                          POST   /notifications(.:format)                                                                          notifications#create
#                         new_notification GET    /notifications/new(.:format)                                                                      notifications#new
#                        edit_notification GET    /notifications/:id/edit(.:format)                                                                 notifications#edit
#                             notification GET    /notifications/:id(.:format)                                                                      notifications#show
#                                          PATCH  /notifications/:id(.:format)                                                                      notifications#update
#                                          PUT    /notifications/:id(.:format)                                                                      notifications#update
#                                          DELETE /notifications/:id(.:format)                                                                      notifications#destroy
#                             preview_jobs POST   /jobs/preview(.:format)                                                                           jobs#preview
#                                     jobs GET    /jobs(.:format)                                                                                   jobs#index
#                                          POST   /jobs(.:format)                                                                                   jobs#create
#                                  new_job GET    /jobs/new(.:format)                                                                               jobs#new
#                                 edit_job GET    /jobs/:id/edit(.:format)                                                                          jobs#edit
#                                      job PATCH  /jobs/:id(.:format)                                                                               jobs#update
#                                          PUT    /jobs/:id(.:format)                                                                               jobs#update
#                                          DELETE /jobs/:id(.:format)                                                                               jobs#destroy
#                           cancel_job_run PATCH  /job_runs/:id/cancel(.:format)                                                                    job_runs#cancel
#                             logs_job_run GET    /job_runs/:id/logs(.:format)                                                                      job_runs#logs
#                                 job_runs GET    /job_runs(.:format)                                                                               job_runs#index
#                                          POST   /job_runs(.:format)                                                                               job_runs#create
#                                  job_run GET    /job_runs/:id(.:format)                                                                           job_runs#show
#                                          DELETE /job_runs/:id(.:format)                                                                           job_runs#destroy
#         turbo_recede_historical_location GET    /recede_historical_location(.:format)                                                             turbo/native/navigation#recede
#         turbo_resume_historical_location GET    /resume_historical_location(.:format)                                                             turbo/native/navigation#resume
#        turbo_refresh_historical_location GET    /refresh_historical_location(.:format)                                                            turbo/native/navigation#refresh
#            rails_postmark_inbound_emails POST   /rails/action_mailbox/postmark/inbound_emails(.:format)                                           action_mailbox/ingresses/postmark/inbound_emails#create
#               rails_relay_inbound_emails POST   /rails/action_mailbox/relay/inbound_emails(.:format)                                              action_mailbox/ingresses/relay/inbound_emails#create
#            rails_sendgrid_inbound_emails POST   /rails/action_mailbox/sendgrid/inbound_emails(.:format)                                           action_mailbox/ingresses/sendgrid/inbound_emails#create
#      rails_mandrill_inbound_health_check GET    /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#health_check
#            rails_mandrill_inbound_emails POST   /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#create
#             rails_mailgun_inbound_emails POST   /rails/action_mailbox/mailgun/inbound_emails/mime(.:format)                                       action_mailbox/ingresses/mailgun/inbound_emails#create
#           rails_conductor_inbound_emails GET    /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#index
#                                          POST   /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#create
#        new_rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/new(.:format)                                      rails/conductor/action_mailbox/inbound_emails#new
#            rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                      rails/conductor/action_mailbox/inbound_emails#show
# new_rails_conductor_inbound_email_source GET    /rails/conductor/action_mailbox/inbound_emails/sources/new(.:format)                              rails/conductor/action_mailbox/inbound_emails/sources#new
#    rails_conductor_inbound_email_sources POST   /rails/conductor/action_mailbox/inbound_emails/sources(.:format)                                  rails/conductor/action_mailbox/inbound_emails/sources#create
#    rails_conductor_inbound_email_reroute POST   /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format)                               rails/conductor/action_mailbox/reroutes#create
# rails_conductor_inbound_email_incinerate POST   /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format)                            rails/conductor/action_mailbox/incinerates#create
#                       rails_service_blob GET    /rails/active_storage/blobs/redirect/:signed_id/*filename(.:format)                               active_storage/blobs/redirect#show
#                 rails_service_blob_proxy GET    /rails/active_storage/blobs/proxy/:signed_id/*filename(.:format)                                  active_storage/blobs/proxy#show
#                                          GET    /rails/active_storage/blobs/:signed_id/*filename(.:format)                                        active_storage/blobs/redirect#show
#                rails_blob_representation GET    /rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations/redirect#show
#          rails_blob_representation_proxy GET    /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)    active_storage/representations/proxy#show
#                                          GET    /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format)          active_storage/representations/redirect#show
#                       rails_disk_service GET    /rails/active_storage/disk/:encoded_key/*filename(.:format)                                       active_storage/disk#show
#                update_rails_disk_service PUT    /rails/active_storage/disk/:encoded_token(.:format)                                               active_storage/disk#update
#                     rails_direct_uploads POST   /rails/active_storage/direct_uploads(.:format)                                                    active_storage/direct_uploads#create
