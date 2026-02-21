class Postmany::Adapters::LocalFilesystem < Postmany::Ports::Filesystem
  def read(path : String) : String
    File.read(path)
  end

  def write(path : String, content : String) : Nil
    File.write(path, content)
  end

  def ensure_parent_dir(path : String) : Nil
    Dir.mkdir_p(Path[path].dirname)
  end
end
