# frozen_string_literal: true

RSpec.describe "Repositories" do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /repositories" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the index page" do
        get repositories_path

        expect(response).to have_http_status(:ok)
      end

      context "when a query parameter is present" do
        it "filters repositories by name" do
          matching_repository = create(:repository, user:, name: "System files")
          non_matching_repository = create(:repository, user:, name: "Documents")

          get repositories_path, params: { query: "system" }

          expect(response.body).to include(matching_repository.name)
          expect(response.body).not_to include(non_matching_repository.name)
        end

        it "filters repositories by description" do
          matching_repository = create(:repository, user:, description: "System configuration")
          non_matching_repository = create(:repository, user:, description: "Important stuff")

          get repositories_path, params: { query: "configuration" }

          expect(response.body).to include(matching_repository.description)
          expect(response.body).not_to include(non_matching_repository.description)
        end

        it "is case insensitive" do
          repository = create(:repository, user:, name: "System files")

          get repositories_path, params: { query: "SYSTEM" }

          expect(response.body).to include(repository.name)
        end

        it "handles special SQL characters safely" do
          repository = create(:repository, user:, name: "$$$ files")

          get repositories_path, params: { query: "$$$" }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include(repository.name)
        end

        it "returns empty results for non-matching query" do
          create(:repository, user:, name: "Some Repository")

          get repositories_path, params: { query: "nonexistent" }

          expect(response).to have_http_status(:ok)
        end
      end

      context "when sort parameters are present" do
        it "sorts repositories by name ascending" do
          z_repo = create(:repository, user:, name: "Zebra repo")
          a_repo = create(:repository, user:, name: "Alpha repo")

          get repositories_path, params: { sort: "name", direction: "asc" }

          expect(response.body.index(a_repo.name)).to be < response.body.index(z_repo.name)
        end

        it "sorts repositories by name descending" do
          z_repo = create(:repository, user:, name: "Zebra repo")
          a_repo = create(:repository, user:, name: "Alpha repo")

          get repositories_path, params: { sort: "name", direction: "desc" }

          expect(response.body.index(z_repo.name)).to be < response.body.index(a_repo.name)
        end

        it "falls back to default sort when column is not allowed" do
          create(:repository, user:)

          get repositories_path, params: { sort: "read_only", direction: "asc" }

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get repositories_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /repositories/new" do
    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the new page" do
        get new_repository_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get new_repository_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /repositories" do
    let(:valid_params) { { repository: { name: "My Repo", path: "/data/backup", repository_type: "local" } } }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "creates the repository for the current user and redirects to the index" do
        expect { post repositories_path, params: valid_params }
          .to change(user.repositories, :count).by(1)

        expect(response).to redirect_to(repositories_path)
      end

      it "displays success message" do
        post repositories_path, params: valid_params

        follow_redirect!

        expect(response.body).to include(I18n.t("repositories.create.success"))
      end

      context "with invalid params" do
        let(:invalid_params) { { repository: { name: "", path: "", repository_type: "local" } } }

        it "renders the new page with errors" do
          post repositories_path, params: invalid_params

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not create a repository" do
          expect { post repositories_path, params: invalid_params }
            .not_to change(Repository, :count)
        end
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        post repositories_path, params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /repositories/:id/edit" do
    let(:repository) { create(:repository, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "renders the edit page" do
        get edit_repository_path(repository)

        expect(response).to have_http_status(:ok)
      end
    end

    context "when repository belongs to another user" do
      let(:repository) { create(:repository, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        get edit_repository_path(repository)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get edit_repository_path(repository)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /repositories/:id" do
    let(:repository) { create(:repository, user:) }
    let(:update_params) { { repository: { name: "Updated Repo" } } }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "updates the repository and redirects to the index" do
        patch repository_path(repository), params: update_params

        expect(repository.reload.name).to eq("Updated Repo")
        expect(response).to redirect_to(repositories_path)
      end

      it "displays success message" do
        patch repository_path(repository), params: update_params

        follow_redirect!

        expect(response.body).to include(I18n.t("repositories.update.success"))
      end

      context "with invalid params" do
        let(:invalid_params) { { repository: { name: "", path: "" } } }

        it "renders the edit page with errors" do
          patch repository_path(repository), params: invalid_params

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "when repository belongs to another user" do
      let(:repository) { create(:repository, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        patch repository_path(repository), params: update_params

        expect(response).to have_http_status(:forbidden)
      end

      it "does not update the repository" do
        expect do
          patch repository_path(repository), params: update_params
        end.not_to(change { repository.reload.name })
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        patch repository_path(repository), params: update_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /repositories/:id" do
    let!(:repository) { create(:repository, user:) }

    context "when authenticated" do
      before { sign_in user, scope: :user }

      it "destroys the repository and redirects to the index" do
        expect do
          delete repository_path(repository)
        end.to change(Repository, :count).by(-1)

        expect(response).to redirect_to(repositories_path)
      end

      it "displays success message" do
        delete repository_path(repository)

        follow_redirect!

        expect(response.body).to include(I18n.t("repositories.destroy.success"))
      end
    end

    context "when repository belongs to another user" do
      let!(:repository) { create(:repository, user: other_user) }

      before { sign_in user, scope: :user }

      it "returns forbidden" do
        delete repository_path(repository)

        expect(response).to have_http_status(:forbidden)
      end

      it "does not destroy the repository" do
        expect do
          delete repository_path(repository)
        end.not_to change(Repository, :count)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        delete repository_path(repository)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
