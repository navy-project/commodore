require 'json'

class MockEtcd
  def keys
    @keys ||= {}
  end

  def get(key)
    keys[key]
  end

  def set(key, value)
    keys[key] = value
  end

  def setJSON(key, value)
    keys[key] = value.to_json
  end

  def getJSON(key)
    value = keys[key] || "{}"
    JSON.parse(value)
  end

  def queueJSON(key, value)
    q = keys[key] ||= []
    q << value.to_json
  end

  def getQueue(key)
    q = keys[key] ||= []
    q.map {|v| JSON.parse(v) }
  end

  def ls(key)
    keys.keys.select {|k| k.start_with? key}
  end

  def delete(key, options = {})
    if options[:recursive]
      ls(key).each do |k|
        keys.delete k
      end
    else
      keys.delete key
    end
  end
end

