class Contact
  attr_reader :uri, :mobile_no, :nickname, :impresa, :nickname

  def initialize(uri, attrs)
    @uri = uri
    @mobile_no = attrs["mobile-no"]
    @nickname = attrs["nickname"]
    @impresa = attrs["impresa"]
    @nickname = attrs["nickname"]
  end
end
