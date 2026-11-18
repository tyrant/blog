# frozen_string_literal: true

# Refreshes the Substack Favourites feed — each favourite's recent posts and Notes.
class RefreshSubstackFavouritesJob < ApplicationJob
  include JobProgressReporting

  queue_as :default

  PROGRESS_KEY = "refresh_substack_favourites"

  def perform
    with_progress(PROGRESS_KEY, label: "Refresh Substack Favourites feed", total: 0) do |progress|
      Substack::FavouritesRefresher.execute(progress: progress)
    end
  end
end
