class Fetion
  class Message
    attr_reader :sip, :sent_at, :text

    def initialize(sip, sent_at, text)
      @sip = sip
      @sent_at = sent_at
      @text = text
    end
  end
end
