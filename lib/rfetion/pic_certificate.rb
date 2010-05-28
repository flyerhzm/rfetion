class PicCertificate
  attr_reader :pid, :pic

  def initialize(pid, pic)
    @pid = pid
    @pic = pic
  end

  def self.parse(c)
    PicCertificate.new(c['id'], c['pic'])
  end

  def to_json(*args)
    {:pid => @pid, :pic => @pic}
  end
end
