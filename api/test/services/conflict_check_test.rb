require "test_helper"

class ConflictCheckTest < ActiveSupport::TestCase
  test "edit distance" do
    assert_equal 3, ConflictCheck.levenshtein("kitten", "sitting")
    assert_equal 0, ConflictCheck.levenshtein("acme", "acme")
    assert_equal 4, ConflictCheck.levenshtein("", "abcd")
  end

  test "normalises company suffixes, case and punctuation" do
    assert_equal "acme", ConflictCheck.normalize("ACME Corp.")
    assert_equal "acme", ConflictCheck.normalize("Acme Corporation")
    assert_equal "smith jones", ConflictCheck.normalize("Smith & Jones, LLP")
  end

  test "finds existing clients and adverse parties, including typos" do
    make_client("John Smith")
    make_matter(client: make_client("Maple Holdings Ltd."), adverse_party: "Acme Corporation")

    by_name = ->(q) { ConflictCheck.call(q).map(&:name) }
    assert_equal [ "John Smith" ], by_name.call("Jonh Smith")
    assert_equal [ "Acme Corporation" ], by_name.call("ACME Corp.")
    assert_equal "adverse party", ConflictCheck.call("acme inc").first.role
    assert_empty by_name.call("Jane Doe")
  end

  test "exact matches score 1 and come first" do
    make_client("Riverside Dental")
    make_client("Riverside Dentals")
    matches = ConflictCheck.call("Riverside Dental")
    assert_equal [ 1.0, "same name" ], [ matches.first.score, matches.first.reason ]
    assert_operator matches.last.score, :<, 1.0
  end
end
