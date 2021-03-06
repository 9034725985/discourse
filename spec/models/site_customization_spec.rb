require 'spec_helper'

describe SiteCustomization do

  before do
    SiteCustomization.clear_cache!
  end

  let :user do
    Fabricate(:user)
  end

  let :customization_params do
    {name: 'my name', user_id: user.id, header: "my awesome header", stylesheet: "my awesome css", mobile_stylesheet: nil, mobile_header: nil}
  end

  let :customization do
    SiteCustomization.create!(customization_params)
  end

  let :customization_with_mobile do
    SiteCustomization.create!(customization_params.merge(mobile_stylesheet: ".mobile {better: true;}", mobile_header: "fancy mobile stuff"))
  end

  it 'should set default key when creating a new customization' do
    s = SiteCustomization.create!(name: 'my name', user_id: user.id)
    expect(s.key).not_to eq(nil)
  end

  it 'can enable more than one style at once' do
    c1 = SiteCustomization.create!(name: '2', user_id: user.id, header: 'World',
                              enabled: true, mobile_header: 'hi', footer: 'footer',
                              stylesheet: '.hello{.world {color: blue;}}')

    SiteCustomization.create!(name: '1', user_id: user.id, header: 'Hello',
                              enabled: true, mobile_footer: 'mfooter',
                              mobile_stylesheet: '.hello{margin: 1px;}',
                              stylesheet: 'p{width: 1px;}'
                             )

    expect(SiteCustomization.custom_header).to eq("Hello\nWorld")
    expect(SiteCustomization.custom_header(nil, :mobile)).to eq("hi")
    expect(SiteCustomization.custom_footer(nil, :mobile)).to eq("mfooter")
    expect(SiteCustomization.custom_footer).to eq("footer")

    desktop_css = SiteCustomization.custom_stylesheet
    expect(desktop_css).to match(Regexp.new("#{SiteCustomization::ENABLED_KEY}.css\\?target=desktop"))

    mobile_css = SiteCustomization.custom_stylesheet(nil, :mobile)
    expect(mobile_css).to match(Regexp.new("#{SiteCustomization::ENABLED_KEY}.css\\?target=mobile"))

    expect(SiteCustomization.enabled_stylesheet_contents).to match(/\.hello \.world/)

    # cache expiry
    c1.enabled = false
    c1.save

    expect(SiteCustomization.custom_stylesheet).not_to eq(desktop_css)
    expect(SiteCustomization.enabled_stylesheet_contents).not_to match(/\.hello \.world/)
  end

  it 'should be able to look up stylesheets by key' do
    c = SiteCustomization.create!(name: '2', user_id: user.id,
                              enabled: true,
                              stylesheet: '.hello{.world {color: blue;}}',
                              mobile_stylesheet: '.world{.hello{color: black;}}')

    expect(SiteCustomization.custom_stylesheet(c.key, :mobile)).to match(Regexp.new("#{c.key}.css\\?target=mobile"))
    expect(SiteCustomization.custom_stylesheet(c.key)).to match(Regexp.new("#{c.key}.css\\?target=desktop"))

  end


  it 'should allow including discourse styles' do
    c = SiteCustomization.create!(user_id: user.id, name: "test", stylesheet: '@import "desktop";', mobile_stylesheet: '@import "mobile";')
    expect(c.stylesheet_baked).not_to match(/Syntax error/)
    expect(c.stylesheet_baked.length).to be > 1000
    expect(c.mobile_stylesheet_baked).not_to match(/Syntax error/)
    expect(c.mobile_stylesheet_baked.length).to be > 1000
  end

  it 'should provide an awesome error on failure' do
    c = SiteCustomization.create!(user_id: user.id, name: "test", stylesheet: "$black: #000; #a { color: $black; }\n\n\nboom", header: '')
    expect(c.stylesheet_baked).to match(/Syntax error/)
    expect(c.mobile_stylesheet_baked).not_to be_present
  end

  it 'should provide an awesome error on failure for mobile too' do
    c = SiteCustomization.create!(user_id: user.id, name: "test", stylesheet: '', header: '', mobile_stylesheet: "$black: #000; #a { color: $black; }\n\n\nboom", mobile_header: '')
    expect(c.mobile_stylesheet_baked).to match(/Syntax error/)
    expect(c.stylesheet_baked).not_to be_present
  end


end
