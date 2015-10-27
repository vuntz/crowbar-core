#
# Copyright 2015, SUSE LINUX GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class RepositoriesController < ApplicationController
  before_filter :reload_registry
  #
  # Repository Check
  #
  # Provides the restful api call for
  # Repository Checks 	/utils/repositories 	GET 	Returns a json list of checked repositories
  # Renders an HTML view in the UI
  def index
    all_repos = Crowbar::Repository.check_all_repos
    grouped_repos = {}

    # create one group of repo per platform/arch
    all_repos.each do |repo|
      key = "#{repo.platform}-#{repo.arch}"
      unless grouped_repos.key? key
        grouped_repos[key] = { platform: repo.platform, arch: repo.arch, repos: [] }
      end
      grouped_repos[key]["repos"] << repo
    end

    # inside each group, sort the repos
    grouped_repos.each do |key, value|
      value["repos"].sort! do |a, b|
        required_a = RepositoriesHelper.repository_required_to_i(a.required)
        required_b = RepositoriesHelper.repository_required_to_i(b.required)
        [required_a, a.name] <=> [required_b, b.name]
      end
    end

    # get an array of groups, sorted by platform/arch
    @repos_groups = grouped_repos.to_a.sort.map { |key, value| value }

    respond_to do |format|
      format.html { @repos_groups }
      format.xml { render xml: @repos_groups }
      format.json { render json: @repos_groups }
    end
  end

  # update the state of the repositories (active/disabled)
  # /utils/repositories/sync   POST
  def sync
    unless params["repo"].nil?
      ProvisionerService.new(logger).synchronize_repositories(params["repo"])
    end

    redirect_to repositories_path
  end

  #
  # Activate a single Repository
  #
  # Provides the restful api call for
  # Activate a Repository   /utils/repositories/activate   POST  Creates Repository DataBagItem
  # required parameters: platform, arch, repo
  def activate
    return render_not_found if params[:platform].nil? || params[:arch].nil? || params[:repo].nil?
    ret, _message = ProvisionerService.new(logger).enable_repository(params[:platform], params[:arch], params[:repo])
    respond_to do |format|
      case ret
      when 200
        format.json { head :ok }
        format.html { redirect_to repositories_url }
      when 404
        render_not_found
      else
        format.json do
          render json: { error: I18n.t("cannot_activate_repo", scope: "error", id: params[:repo]) },
                 status: :unprocessable_entity
        end
        format.html do
          flash[:alert] = I18n.t("cannot_activate_repo", scope: "error", id: params[:repo])
          redirect_to repositories_url
        end
      end
    end
  end

  #
  # Deactivate a single Repository
  #
  # Provides the restful api call for
  # Deactivate a Repository   /utils/repositories/deactivate   POST   Destroys Repository DataBagItem
  # required parameters: platform, arch, repo
  def deactivate
    return render_not_found if params[:platform].nil? || params[:arch].nil? || params[:repo].nil?
    ret, _message = ProvisionerService.new(logger).disable_repository(params[:platform], params[:arch], params[:repo])
    respond_to do |format|
      case ret
      when 200
        format.json { head :ok }
        format.html { redirect_to repositories_url }
      when 404
        render_not_found
      else
        format.json do
          render json: { error: I18n.t("cannot_deactivate_repo", scope: "error", id: params[:repo]) },
                 status: :unprocessable_entity
        end
        format.html do
          flash[:alert] = I18n.t("cannot_deactivate_repo", scope: "error", id: params[:repo])
          redirect_to repositories_url
        end
      end
    end
  end

  #
  # Activate all Repositories
  #
  # Provides the restful api call for
  # Activate all Repositories   /utils/repositories/activate_all   POST  Creates Repository DataBagItem
  def activate_all
    ProvisionerService.new(logger).enable_all_repositories
    respond_to do |format|
      format.json { head :ok }
      format.html { redirect_to repositories_url }
    end
  end

  #
  # Deactivate all Repositories
  #
  # Provides the restful api call for
  # Deactivate all Repositories   /utils/repositories/deactivate_all   POST   Destroys Repository DataBagItem
  def deactivate_all
    ProvisionerService.new(logger).disable_all_repositories
    respond_to do |format|
      format.json { head :ok }
      format.html { redirect_to repositories_url }
    end
  end

  protected

  def reload_registry
    Crowbar::Repository.load!
  end
end
