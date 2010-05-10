class Fetion
  class Contact
    attr_reader :sid, :uri, :mobile_no, :nickname, :impresa, :nickname

    def initialize(attrs)
      @sid = attrs["sid"]
      @uri = attrs["su"]
      @mobile_no = attrs["m"]
      @nickname = attrs["n"]
      @impresa = attrs["i"]
    end
  end
end
