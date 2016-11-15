# frozen_string_literal: true
module RubyCritic
  module ViewHelpers
    def timeago_tag(time)
      "<time class='js-timeago' datetime='#{time}'>#{time}</time>"
    end

    def javascript_tag(file)
      "<script src='" + asset_path("javascripts/#{file}.js").to_s + "'></script>"
    end

    def stylesheet_path(file)
      asset_path("stylesheets/#{file}.css")
    end

    def asset_path(file)
      relative_path("assets/#{file}")
    end

    def file_path(file)
      relative_path(file)
    end

    def smell_location_path(location)
      Config.set_location ? "file://#{File.expand_path(Config.feature_root_directory)}/#{location.pathname.sub_ext('.html')}#L#{location.line}" : file_path("#{location.pathname.sub_ext('.html')}#L#{location.line}")
    end

    def code_index_path(branch)
      return base_code_index_path if branch == 'base'
      return feature_code_index_path if branch == 'feature'
      build_code_index_path 
    end

    def base_code_index_path
      "file://#{File.expand_path(Config.base_root_directory)}/overview.html"
    end

    def feature_code_index_path
      "file://#{File.expand_path(Config.feature_root_directory)}/overview.html"
    end

    def build_code_index_path
      "file://#{File.expand_path(Config.build_root_directory)}/code_index.html"
    end

    private

    def relative_path(file)
      (root_directory + file).relative_path_from(file_directory)
    end

    def file_directory
      raise NotImplementedError,
            "The #{self.class} class must implement the #{__method__} method."
    end

    def root_directory
      raise NotImplementedError,
            "The #{self.class} class must implement the #{__method__} method."
    end
  end
end
