module BackgroundProcess::IOHelpers
  extend self
  def detect(streams = [], timeout = nil, &block)
    begin
      Timeout::timeout(timeout) do
        # Something that should be interrupted if it takes too much time...
        until streams.empty?
          active_streams, _, _ = Kernel.select(streams, nil, nil, 1)
          active_streams.each do |s|
            (streams -= [s]; next) if s.eof?
            content = s.gets
            if result = (block.arity == 1 ? yield(content) : yield(s, content))
              return result
            end
          end if active_streams
        end
      end
      nil
    rescue Timeout::Error
      nil
    end

  end
end