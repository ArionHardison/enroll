Feature: User attempts to view their American Indian or Alaska Native status

  Background: User logs in and visits applicant's other income page and is not an indian or alaska tribe
    Given bs4_consumer_flow feature is enabled
    Given a consumer, with a family, exists
    And is logged in
    And the consumer is RIDP verified
    When the user navigates to the DOCUMENTS tab

  Scenario: New User with American Indian or Alaska Native status with feature enabled
    Given the ai_an_self_attestation feature is enabled
    And the consumer is new user with attested American Indian or Alaska Native status
    Then user should not see an American Indian or Alaska Native status

  Scenario: Existing User with American Indian or Alaska Native status with feature enabled
    Given the ai_an_self_attestation feature is enabled
    And the consumer is existing user with outstanding American Indian or Alaska Native status
    Then user should see an American Indian or Alaska Native status

  Scenario: Existing User with American Indian or Alaska Native status with feature enabled without outstanding state
    Given the ai_an_self_attestation feature is enabled
    And the consumer is existing user with negative response received American Indian or Alaska Native status
    Then user should not see an American Indian or Alaska Native status

  Scenario: New User with American Indian or Alaska Native status with feature disabled
    Given the ai_an_self_attestation feature is disabled
    And the consumer is new user with negative response received American Indian or Alaska Native status
    Then user should see an American Indian or Alaska Native status

  Scenario: Existing User with American Indian or Alaska Native status with feature disabled
    Given the ai_an_self_attestation feature is disabled
    And the consumer is existing user with outstanding American Indian or Alaska Native status
    Then user should see an American Indian or Alaska Native status