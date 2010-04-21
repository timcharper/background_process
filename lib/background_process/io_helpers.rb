module BackgroundProcess::IOHelpers
  extend self
  def detect(streams = [], timeout = nil, &block)
    begin
      Timeout::timeout(timeout) do
        # Something that should be interrupted if it takes too much time...
        while true
          available_streams, _, _ = Kernel.select(streams, nil, nil, 1)
          available_streams.each do |s|
            content = s.gets
            if result = (block.arity == 1 ? yield(content) : yield(s, content))
              return result
            end
          end if available_streams
        end
      end
      true
    rescue Timeout::Error
      nil
    end

  end
end