class ApplicationController < ActionController::Base

  before_action :comfy_doohickeys_instance_eval
  before_action :unstringly_type_nsfw_cookies
  before_action :instanceify_nsfw_cookies
  before_action :init_nav_items
  before_action :init_amazon_tlds, only: [:phwoar, :superb, :supremacy, :praetorian]

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
    @amazon = 'B0CKBRWKC3'
    @non_amazons = [{
      url: 'https://play.google.com/store/books/details/Mikey_Clarke_The_Sex_Commandos_Thwart_The_Third_Va?id=oivcEAAAQBAJ',
      img: 'google-play.png'
    }, {
      url: 'https://books.apple.com/nz/book/the-sex-commandos-thwart-the-third-vaginal-apocalypse/id6468569184',
      img: 'apple-books.png'
    }, {
      url: 'https://www.barnesandnoble.com/w/1144217726',
      img: 'barnes_and_noble.png'
    }, {
      url: 'https://www.kobo.com/nz/en/ebook/the-sex-commandos-thwart-the-third-vaginal-apocalypse',
      img: 'rakutenkobo.png'
    }, {
      url: 'https://www.everand.com/book/675241188',
      img: 'logo-everand-2x.png'
    }, {
      url: 'https://www.24symbols.com/book/english/mikey-clarke/?id=4564179',
      img: '24symbols.png'
    }, {
      url: 'https://books.rakuten.co.jp/rk/433d4edd900b3c52b18dc25f4a077cae/',
      img: 'rakuten_jp_logo_header.png'
    }, {
      url: 'https://kk.bookmate.com/books/PPZnTTOA',
      img: 'bookmate2.png'
    }, {
      url: 'https://www.booktopia.com.au/the-sex-commandos-thwart-the-third-vaginal-apocalypse-mikey-clarke/ebook/9798890082770.html',
      img: 'booktopia-logo-positive.png'
    }]
  end

  def superb
    @amazon = 'B0CNXPRP6R'
    @non_amazons = [{
      url: 'https://play.google.com/store/books/details/Mikey_Clarke_The_Sex_Commandos_Thwart_The_Third_Va?id=nGLlEAAAQBAJ',
      img: 'google-play.png'
    }, {
      url: 'https://books.apple.com/nz/book/id6473009270',
      img: 'apple-books.png'
    }, {
      url: 'https://www.barnesandnoble.com/w/the-sex-commandos-thwart-the-third-vaginal-apocalypse-mikey-clarke/1144406893?ean=2940167623583',
      img: 'barnes_and_noble.png'
    }, {
      url: 'https://www.kobo.com/nz/en/ebook/the-sex-commandos-thwart-the-third-vaginal-apocalypse-1',
      img: 'rakutenkobo.png'
    }, {
      url: 'https://www.everand.com/book/686942507/The-Sex-Commandos-Thwart-The-Third-Vaginal-Apocalypse-Part-2-6-The-Soviet-Sluts-Superb',
      img: 'logo-everand-2x.png'
    }, {
      url: 'https://www.24symbols.com/book/english/mikey-clarke/the-sex-commandos-thwart-the-third-vaginal-apocalypse---part-2-6-the-soviet-sluts-superb?id=4606234',
      img: '24symbols.png'
    }, {
      url: 'https://books.rakuten.co.jp/rk/47c27c2f87c537ae8376abd6a31a4893/',
      img: 'rakuten_jp_logo_header.png'
    }, {
      url: 'https://kk.bookmate.com/books/vzDvMUQ3',
      img: 'bookmate2.png'
    }, {
      url: 'https://www.booktopia.com.au/the-sex-commandos-thwart-the-third-vaginal-apocalypse-mikey-clarke/ebook/6610000492497.html',
      img: 'booktopia-logo-positive.png'
    }]
  end

  def supremacy
    @amazon = 'B0CTHHZM15'
    @non_amazons = [{
      url: 'https://play.google.com/store/books/details/Mikey_Clarke_The_Sex_Commandos_Thwart_The_Third_Va?id=Zz_xEAAAQBAJ',
      img: 'google-play.png'
    }, {
      url: 'https://books.apple.com/nz/book/the-sex-commandos-thwart-the-third-vaginal-apocalypse/id6476866040',
      img: 'apple-books.png'
    }, {
      url: 'https://www.barnesandnoble.com/w/the-sex-commandos-thwart-the-third-vaginal-apocalypse-mikey-clarke/1144744255?ean=2940168047364',
      img: 'barnes_and_noble.png'
    }, {
      url: 'https://www.kobo.com/nz/en/ebook/the-sex-commandos-thwart-the-third-vaginal-apocalypse-2',
      img: 'rakutenkobo.png'
    }, {
      url: 'https://www.everand.com/book/702129151/The-Sex-Commandos-Thwart-The-Third-Vaginal-Apocalypse-Part-3-6-The-Cervical-Supremacy',
      img: 'logo-everand-2x.png'
    }, {
      url: 'https://www.24symbols.com/book/english/mikey-clarke/the-sex-commandos-thwart-the-third-vaginal-apocalypse---part-3-6-the-cervical-supremacy?id=4653266',
      img: '24symbols.png'
    }, {
      url: 'https://books.rakuten.co.jp/rk/0c8271b63edc34169c6efc4ef60fc39a/',
      img: 'rakuten_jp_logo_header.png'
    }, {
      url: 'https://kk.bookmate.com/books/CWGRBSAT',
      img: 'bookmate2.png'
    }, {
      url: 'https://www.booktopia.com.au/the-sex-commandos-thwart-the-third-vaginal-apocalypse-mikey-clarke/ebook/6610000516087.html',
      img: 'booktopia-logo-positive.png'
    }]
  end
  
  def praetorian
    @amazon = 'B0D88MR374'
    @non_amazons = [{
      url: 'https://play.google.com/store/books/details/Mikey_Clarke_The_Sex_Commandos_Thwart_The_Third_Va?id=skgQEQAAQBAJ',
      img: 'google-play.png'
    }, {
      url: 'https://books.apple.com/nz/book/the-sex-commandos-thwart-the-third-vaginal/id6504763043',
      img: 'apple-books.png'
    }, {
      url: 'https://www.barnesandnoble.com/w/the-sex-commandos-thwart-the-third-vaginal-apocalypse-part-4-6-mikey-clarke/1145886676?ean=2940168133104',
      img: 'barnes_and_noble.png'
    }, {
      url: 'https://www.kobo.com/nz/en/ebook/the-sex-commandos-thwart-the-third-vaginal-apocalypse-part-4-6',
      img: 'rakutenkobo.png'
    }, {
      url: 'https://www.everand.com/book/744896872/The-Sex-Commandos-Thwart-The-Third-Vaginal-Apocalypse-part-4-6-The-Praetorian-Prostitutes',
      img: 'logo-everand-2x.png'
    }, {
      url: 'https://www.24symbols.com/book/english/mikey-clarke/the-sex-commandos-thwart-the-third-vaginal-apocalypse-part-4-6---the-praetorian-prostitutes?id=4770213',
      img: '24symbols.png'
    }, {
      url: 'https://books.rakuten.co.jp/rk/d1cb253a0ed438dca2f7d440f44a193a/',
      img: 'rakuten_jp_logo_header.png'
    }, {
      url: 'https://kk.bookmate.com/books/efUCrhsm',
      img: 'bookmate2.png'
    }, {
      url: 'https://www.booktopia.com.au/the-sex-commandos-thwart-the-third-vaginal-apocalypse-part-4-6-mikey-clarke/ebook/6610000601967.html',
      img: 'booktopia-logo-positive.png'
    }]
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
        }, {
          key: 'praetorian',
          label: 'Apocalypse 4/6: the Praetorian Prostitutes',
          path: praetorian_path
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
    @amazon_tlds = %w(.com .co.uk .co.jp .de .com.au .ca .fr .com.br .es .it .com.mx .nl)
  end
end
