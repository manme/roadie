# encoding: UTF-8
require 'spec_helper'

module Roadie
  describe UrlGenerator do
    it "is initialized with URL options" do
      expect(UrlGenerator.new(host: "foo.com").url_options).to eq({host: "foo.com"})
    end

    it "raises an argument error if no URL options are specified" do
      expect {
        UrlGenerator.new(nil)
      }.to raise_error ArgumentError, /url options/i
    end

    it "raises an argument error if no host is specified" do
      expect {
        UrlGenerator.new(port: 3000)
      }.to raise_error ArgumentError, /host/i
    end

    it "raises an argument error if unknown option is passed" do
      expect {
        UrlGenerator.new(host: "localhost", secret: true)
      }.to raise_error ArgumentError, /secret/
    end

    describe "generating URLs" do
      def url(path, options = {})
        UrlGenerator.new(options).generate_url(path)
      end

      it "uses the given host" do
        expect(url("/hello.jpg", host: "goats.com")).to eq("http://goats.com/hello.jpg")
      end

      it "uses the given port" do
        expect(url("/", host: "example.com", port: 1337)).to eq("http://example.com:1337/")
      end

      it "uses the given scheme" do
        expect(url("/", host: "example.com", scheme: "https")).to eq("https://example.com/")
      end

      it "regards :protocol as an alias for scheme" do
        expect(url("/", host: "example.com", protocol: "https")).to eq("https://example.com/")
      end

      it "strips extra characters from the scheme" do
        expect(url("/", host: "example.com", scheme: "https://")).to eq("https://example.com/")
      end

      it "uses the given path as a prefix" do
        expect(url("/my_file", host: "example.com", path: "/my_app")).to eq(
          "http://example.com/my_app/my_file"
        )
      end

      it "returns the original URL if it is absolute" do
        expect(url("http://foo.com/", host: "bar.com")).to eq("http://foo.com/")
      end

      it "returns the base URL for blank paths" do
        expect(url("", host: "foo.com")).to eq("http://foo.com")
        expect(url(nil, host: "foo.com")).to eq("http://foo.com")
      end

      it "raises an error on invalid path" do
        expect {
          url("://", host: "example.com")
        }.to raise_error InvalidUrlPath, %r{://}
      end

      it "accepts base paths without a slash in the beginning" do
        expect(url("/bar", host: "example.com", path: "foo")).to eq("http://example.com/foo/bar")
        expect(url("/bar/", host: "example.com", path: "foo/")).to eq("http://example.com/foo/bar/")
      end

      it "accepts input paths without a slash in the beginning" do
        expect(url("bar", host: "example.com", path: "/foo")).to eq("http://example.com/foo/bar")
        expect(url("bar", host: "example.com", path: "/foo/")).to eq("http://example.com/foo/bar")
      end

      it "does not touch data: URIs" do
        expect(url("data:deadbeef", host: "example.com")).to eq("data:deadbeef")
      end

      it "does not touch absolute URLs without schemes" do
        expect(url("//assets.myapp.com/foo.jpg", host: "example.com")).to eq("//assets.myapp.com/foo.jpg")
      end

      it "does not touch custom schemes" do
        expect(url("myapp://", host: "example.com")).to eq("myapp://")
      end

      it "does not care if absolute URLs have parse errors" do
        # Pipe character is invalid inside URLs, but that does not stop a whole
        # lot of templating/emailing systems for using them as template
        # markers.
        expect(url("https://foo.com/%|MARKETING_TOKEN|%", host: "example.com")).to eq("https://foo.com/%|MARKETING_TOKEN|%")
      end
    end

    # URLs in resources that are not based inside the root requires that we may
    # specify a "custom base" to properly handle relative paths. Here's an
    # example:
    #
    #   # /
    #   #  document.html
    #   #  images/
    #   #    bg.png
    #   #  stylesheets/
    #   #    my_style.css
    #
    #   # stylesheets/my_style.css
    #   body { background-image: url(../images/bg.png); }
    #
    # In this example, the stylesheet refers to /images/bg.png by using a
    # relative path from /stylesheets/. In order to understand these cases, we
    # need to specify where the "base" is in relation to the root.
    describe "generating URLs with custom base" do
      it "resolves relative paths" do
        generator = UrlGenerator.new(host: "foo.com")
        expect(generator.generate_url("../images/bg.png", "/stylesheets")).to eq("http://foo.com/images/bg.png")
        expect(generator.generate_url("../images/bg.png", "email/stylesheets")).to eq("http://foo.com/email/images/bg.png")
        expect(generator.generate_url("images/bg.png", "email/")).to eq("http://foo.com/email/images/bg.png")
      end

      it "does not use the base when presented with a root-based path" do
        generator = UrlGenerator.new(host: "foo.com")
        expect(generator.generate_url("/images/bg.png", "/stylesheets")).to eq("http://foo.com/images/bg.png")
        expect(generator.generate_url("/images/bg.png", "email/stylesheets")).to eq("http://foo.com/images/bg.png")
      end
    end
  end
end
