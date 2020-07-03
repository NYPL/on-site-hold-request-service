class ParameterError < StandardError
  def initialize(msg="Parameter error")
    super
  end
end

class NotFoundError < StandardError
  def initialize(msg="Record not found")
    super
  end
end

class InternalError < StandardError
  def initialize(msg="Internal error")
    super
  end
end

class SierraError < StandardError

  def initialize(msg="Sierra Error")
    super
  end
end

class SierraRecordUnavailableError < StandardError
  def initialize(msg="Sierra record not available")
    super
  end
end
