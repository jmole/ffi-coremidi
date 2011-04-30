#!/usr/bin/env ruby

module CoreMIDI

  #
  # Output entity class
  #
  class Output

    include Entity

    # close this output
    def close
      Map.MIDIClientDispose( @client )
      @enabled = false
    end

    # sends a MIDI message comprised of a String of hex digits
    def puts_bytestr(data)
    end

    # sends a MIDI messages comprised of Numeric bytes
    def puts_bytes(*data)
      format = "C" * data.size
      bytes = (FFI::MemoryPointer.new FFI.type_size(:char) * data.size)
      bytes.write_string(data.pack(format))

      if data.first.eql?(0xF0) && data.last.eql?(0xF7)
        puts_sysex(bytes, data.size)
      else
        puts_small(bytes, data.size)
      end
    end

    # send a MIDI message of an indeterminant type
    def puts(*a)
  	  case a.first
        when Array then puts_bytes(*a.first)
    	  when Numeric then puts_bytes(*a)
    	  when String then puts_bytestr(*a)
      end
    end
    alias_method :write, :puts

    # enable this device; also takes a block
    def enable(options = {}, &block)
      client_name = Map::CF.CFStringCreateWithCString( nil, "Client #{@id}: #{@name}", 0 )
      client_ptr = FFI::MemoryPointer.new(:pointer)

      Map.MIDIClientCreate(client_name, nil, nil, client_ptr)
      @client = client_ptr.read_pointer

      port_name = Map::CF.CFStringCreateWithCString(nil, "Port #{@id}: #{@name}", 0)
      outport_ptr = FFI::MemoryPointer.new(:pointer)
      Map.MIDIOutputPortCreate(@client, port_name, outport_ptr)
      @outport = outport_ptr.read_pointer
      @destination = Map.MIDIGetDestination( 0 )

      @enabled = true
      unless block.nil?
      	begin
      		block.call(self)
      	ensure
      		close
      	end
      end
    end
    alias_method :open, :enable
    alias_method :start, :enable

    def self.first
      Entity.first(:output)
    end

    def self.last
      Entity.last(:output)
    end

    def self.all
      Entity.all_by_type[:output]
    end

    private

    def puts_small(bytes, size)
      packet_list = FFI::MemoryPointer.new(256)
      packet_ptr = Map.MIDIPacketListInit(packet_list)

      if Map::SnowLeopard
        packet_ptr = Map.MIDIPacketListAdd(packet_list, 256, packet_ptr, 0, size, bytes)
      else
        # Pass in two 32-bit 0s for the 64 bit time
        packet_ptr = Map.MIDIPacketListAdd(packet_list, 256, packet_ptr, 0, 0, size, bytes)
      end

      Map.MIDISend( @outport, @destination, packet_list )
    end

    def puts_sysex(bytes, size)

      @callback =

      request = Map::MIDISysexSendRequest.new
      request[:destination] = @destination
      request[:data] = bytes
      request[:bytes_to_send] = size
      request[:complete] = 0
      request[:completion_proc] = SysexCompletionCallback
      request[:completion_ref_con] = request

      Map.MIDISendSysex(request)
    end

    SysexCompletionCallback =
      Proc.new do |sysex_request_ptr|
        # this isn't working for some reason
        # as of now, we don't need it though
      end

  end

end