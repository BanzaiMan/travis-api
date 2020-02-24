module Travis::API::V3
  class Queries::Repository < Query
    setup_sidekiq(:repo_sync, queue: :sync, class_name: "Travis::GithubSync::Worker")
    params :id, :slug

    def find
      @find ||= find!
    end

    def star(current_user)
      repository = find
      starred = Models::Star.where(repository_id: repository.id, user_id: current_user.id).first
      Models::Star.create(repository_id: repository.id, user_id: current_user.id) unless starred
      repository
    end

    def unstar(current_user)
      repository = find
      starred = Models::Star.where(repository_id: repository.id, user_id: current_user.id).first
      starred.delete if starred
      repository
    end

    def sync(current_user)
      repository = find
      perform_async(:repo_sync, :sync_repo, repo_id: repository.id, user_id: current_user.id)
      repository
    end

    def update(attrs)
      repository = find
      repository.update_attributes!(attrs)
      repository
    end

    private

    def find!
      return by_slug if slug
      return Models::Repository.find_by_id(id) if id
      raise WrongParams, 'missing repository.id'.freeze
    end

    def by_slug
      if provider.downcase == 'bitbucket'
        url_org = "git@bitbucket.org:#{slug}.git"
        url_com = "git@bitbucket.com:#{slug}.git"
        return Models::Repository.where(
          "(lower(url) = ? or lower(url) = ?) "\
          "and lower(repositories.vcs_type) = ? "\
          "and repositories.invalidated_at is null",
          url_org.downcase,
          url_com.downcase,
          provider.downcase + 'repository'
        ).order("updated_at desc").first
      end

      owner_name, repo_name = slug.split('/')
      Models::Repository.where(
        "lower(repositories.owner_name) = ? "\
        "and lower(repositories.name) = ? "\
        "and lower(repositories.vcs_type) = ? "\
        "and repositories.invalidated_at is null",
        owner_name.downcase,
        repo_name.downcase,
        provider.downcase + 'repository'
      ).order("updated_at desc").first
    end

    def provider
      params['provider'] || 'github'
    end

  end
end
