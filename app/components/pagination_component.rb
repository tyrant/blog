class PaginationComponent < ViewComponent::Base

  DEFAULT_DISTANCE = 1

  def initialize(page_no:, nsfw_banished:, sfw_count:)
    @cur_page_no = page_no.nil? ? 1 : page_no.to_i
    @nsfw_banished = nsfw_banished
    @sfw_count = sfw_count
    @already_displayed_1_to_n_ellipsis = false 
    @already_displayed_n_to_page_count_ellipsis = false
  end

  private

  def n_near_start_cur_end?(n:, distance: DEFAULT_DISTANCE)
    (n - 1).abs <= distance ||
      (@cur_page_no - n).abs <= distance ||
      (pages_total_count - n).abs <= distance
  end

  def prev_page_no
    if @cur_page_no <= 1
      1
    else
      @cur_page_no - 1
    end
  end

  def next_page_no 
    if (@cur_page_no + 1) > pages_total_count 
      pages_total_count
    else
      @cur_page_no + 1
    end
  end

  def page_size
    ComfyBlog.config.posts_per_page
  end

  def cur_page_floor
    (@cur_page_no - 1) * page_size+1
  end

  def cur_page_ceil
    all_posts_count = if @cur_page_no * page_size > posts_total_count
        posts_total_count
      else
        @cur_page_no * page_size
      end

    all_posts_count -= cur_page_nsfw_posts_count if @nsfw_banished
    all_posts_count
  end

  def cur_page_nsfw_posts_count
    page_size - @sfw_count
  end

  def posts_total_count
    Comfy::Blog::Post.published.for_category(params[:category]).count
  end

  def pages_total_count 
    (posts_total_count.to_f / page_size.to_f).ceil
  end
end
