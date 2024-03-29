class ApplicationController < ActionController::Base

  before_action :comfy_doohickeys_instance_eval
  before_action :unstringly_type_nsfw_cookies
  before_action :instanceify_nsfw_cookies
  before_action :init_nav_items
  before_action :init_amazon_tlds, only: [:phwoar, :superb, :supremacy]

  STR_TO_BOOL = [true, false].map { |b| [b.to_s, b] }.to_h
  COOKIES = [
    { code: 'banish',    name: 'banish_nsfw_completely',   default: false },
    { code: 'mouseover', name: 'unblur_nsfw_on_mouseover', default: true  },
    { code: 'always',    name: 'unblur_nsfw_always',       default: false }
  ]

  def index
    redirect_to comfy_blog_posts_path
  end

  def apocalypse
    redirect_to phwoar_path
  end

  def phwoar
  end

  def superb
  end

  def supremacy
  end

  private

  # Much faffing implies this is the least crap location I can find for these
  # particular .instance_eval calls. Still not perfect!
  # I'd normally do .instance_eval calls for model-doohickeys inside /models ...
  # but it seems doing these for third-party AR models, particularly for ones
  # extending ActiveRecord::Base rather than ApplicationRecord, makes /models-
  # based .instance_eval calls not stick. Unsure of the exact reason why, but
  # don't feel inclined to squander even more time investigating. Rr. Hmph. 
  # Fine. Do the includes here instead. Yes we're mixing app logic with data
  # logic, but fuckit. It's my party, bee-hah-chiz <3 :*
  def comfy_doohickeys_instance_eval
    Comfy::Blog::Post.instance_eval { include ComfyBlogPostMethods }
    Comfy::Cms::Category.instance_eval { include ComfyCmsCategoryMethods }
  end

  # Our three NSFW-visibility-options cookies are all boolean. But cookies are
  # stringly typed. Convert all three, 'true'/'false', to true/false.
  def unstringly_type_nsfw_cookies
    COOKIES.each do |cookie|
      STR_TO_BOOL.each do |str, bool|
        request.cookies[cookie[:name]] = bool if request.cookies[cookie[:name]] == str
      end
    end
  end

  # Generate a list of all COOKIES values, each mapping either to this request's
  # incoming actual cookie values, or reverting to cookie[:default] if absent.
  def instanceify_nsfw_cookies
    @nsfw_options = COOKIES.map do |cookie|
      [ cookie[:code], request.cookies.fetch(cookie[:name], cookie[:default]) ]
    end.to_h
  end

  def init_nav_items
    @nav_items = [
      { 
        key: 'sexyverse',
        label: 'The Sexyverse Novels',
        path: apocalypse_path,
        children: [{ 
          key: 'phwoar',
          label: 'Apocalypse 1/6: the Knights of Raw Phwoar',
          path: phwoar_path
        }, { 
          key: 'superb',
          label: 'Apocalypse 2/6: the Soviet Sluts Superb', 
          path: superb_path 
        }, { 
          key: 'supremacy',
          label: 'Apocalypse 3/6: the Cervical Supremacy',
          path: supremacy_path
        }]
      }, { 
        key: 'all-posts',
        label: 'Blog Posts',
        path: comfy_blog_posts_path,
        children: Comfy::Cms::Category.public_names.select(:label).map do |cat|
          { 
            key: cat.label.parameterize,
            label: cat.label,
            path: comfy_blog_posts_path(category: cat.label)
          }
        end
      }
    ]
  end

  def init_amazon_tlds
    @amazon_tlds = %w(.com .nl .co.jp .de .com.au .ca .fr .com.br .es .co.uk .com.mx .it)
  end
end
