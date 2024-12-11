# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `Reports::MfaReport`.
# Please instead update this file by running `bin/tapioca dsl Reports::MfaReport`.


class Reports::MfaReport
  class << self
    sig do
      params(
        report_date: T.untyped,
        block: T.nilable(T.proc.params(job: Reports::MfaReport).void)
      ).returns(T.any(Reports::MfaReport, FalseClass))
    end
    def perform_later(report_date, &block); end

    sig { params(report_date: T.untyped).returns(T.untyped) }
    def perform_now(report_date); end
  end
end
