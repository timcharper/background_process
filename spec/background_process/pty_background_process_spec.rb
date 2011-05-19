require 'spec_helper'

describe PTYBackgroundProcess do
  describe ".run" do
    it "runs a subprocess with streams that are identified as tty's" do
      process = PTYBackgroundProcess.run("env PS1='$' sh")
      process.stdin.should be_tty
      process.stdout.should be_tty
      process.kill
    end

    it "allows bidirectional communication with the process" do
      process = PTYBackgroundProcess.run("env PS1='$' sh")
      process.stdout.getc # wait for the prompt
      process.stdin.puts "echo Hello World"
      process.stdout.gets.chomp.should == "echo Hello World"
      process.stdout.gets.chomp.should == "Hello World"
      process.stdin.puts "exit"
      process.wait
    end

    it "allows you to pass an array of args, which are automatically sanitized" do
      process = PTYBackgroundProcess.run("sh", "-c", "echo hi")
      process.stdout.gets.chomp.should == "hi"
    end

  end

  describe "#exitstatus" do
    it "raises an error if you query it" do
      process = PTYBackgroundProcess.run("exit 1")
      lambda {process.exitstatus}.should raise_error(ArgumentError, /not available/)
    end
  end

  describe "#stderr" do
    it "raises if you try to access it" do
      process = PTYBackgroundProcess.run("exit 1")
      lambda {process.stderr}.should raise_error(ArgumentError, /merged.+stdout/)
    end
  end

  describe "#detect" do
    it "you would expect" do
      process = PTYBackgroundProcess.run("bash -c 'echo output; echo error 1>&2'")
      process.detect { |line| true if line =~ /output/ }.should be_true
      process.detect { |line| true if line =~ /error/ }.should be_true
    end

    it "raises if you try to select :stderr only" do
      process = PTYBackgroundProcess.run("bash -c 'echo output; echo error 1>&2'")
      lambda { process.detect(:stderr) { |line| true } }.should raise_error(ArgumentError, /merged.+stdout/)
    end
  end
end
