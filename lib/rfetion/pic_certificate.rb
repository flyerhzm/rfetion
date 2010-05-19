class PicCertificate
  attr_reader :id, :pic

  def initialize(id, pic)
    @id = id
    @pic = pic
  end

  def self.parse(c)
    PicCertificate.new(c['id'], c['pic'])
  end
end
