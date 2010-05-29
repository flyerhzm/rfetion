class PicCertificate
  attr_reader :pid, :pic, :algorithm

  def initialize(pid, pic, algorithm)
    @pid = pid
    @pic = pic
    @algorithm = algorithm
  end

  def self.parse(c, algorithm)
    PicCertificate.new(c['id'], c['pic'], algorithm)
  end

  def to_json(*args)
    {:pid => @pid, :pic => @pic, :algorithm => @algorithm}
  end
end
