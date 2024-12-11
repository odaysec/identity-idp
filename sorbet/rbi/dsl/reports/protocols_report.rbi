# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `Reports::ProtocolsReport`.
# Please instead update this file by running `bin/tapioca dsl Reports::ProtocolsReport`.


class Reports::ProtocolsReport
  class << self
    sig do
      params(
        date: T.untyped,
        block: T.nilable(T.proc.params(job: Reports::ProtocolsReport).void)
      ).returns(T.any(Reports::ProtocolsReport, FalseClass))
    end
    def perform_later(date = T.unsafe(nil), &block); end

    sig { params(date: T.untyped).returns(T.untyped) }
    def perform_now(date = T.unsafe(nil)); end
  end
end
