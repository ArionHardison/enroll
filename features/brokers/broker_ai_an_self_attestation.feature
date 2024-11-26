Feature: Broker representing a user attempts to view their American Indian or Alaska Native status

  Background: Broker logs in and visits applicant's documents page and has American Indian or Alaska Native status
    Given bs4_consumer_flow feature is enabled
    Given a consumer, with a family, exists
    And the consumer is RIDP verified
    Given a person exists with a Broker user
    And this person has an approved broker role and broker agency profile
    And the consumer has selected the broker to represent them

  Scenario: Broker representing existing user with American Indian or Alaska Native status with feature enabled
    Given the ai_an_self_attestation feature is enabled
    And the Broker user logs into their account
    And the user visits home page
    And the user clicks on the Broker Agency Portal button
    And the user clicks the Families tab
    And the user clicks on the assigned user
    And the consumer is existing user with outstanding American Indian or Alaska Native status
    And the Broker user clicks on the Documents tab from the user's side navigation
    Then broker should see an American Indian or Alaska Native status

  Scenario: Broker representing new user with American Indian or Alaska Native status with feature enabled
    Given the ai_an_self_attestation feature is enabled
    And the Broker user logs into their account
    And the user visits home page
    And the user clicks on the Broker Agency Portal button
    And the user clicks the Families tab
    And the user clicks on the assigned user
    And the consumer is new user with attested American Indian or Alaska Native status
    And the Broker user clicks on the Documents tab from the user's side navigation
    Then broker should not see an American Indian or Alaska Native status

  Scenario: Broker representing existing user with American Indian or Alaska Native status with feature enabled without outstanding state
    Given the ai_an_self_attestation feature is enabled
    And the Broker user logs into their account
    And the user visits home page
    And the user clicks on the Broker Agency Portal button
    And the user clicks the Families tab
    And the user clicks on the assigned user
    And the consumer is new user with negative response received American Indian or Alaska Native status
    And the Broker user clicks on the Documents tab from the user's side navigation
    Then broker should not see an American Indian or Alaska Native status

  Scenario: Broker representing existing user with American Indian or Alaska Native status with feature disabled
    Given the ai_an_self_attestation feature is disabled
    And the Broker user logs into their account
    And the user visits home page
    And the user clicks on the Broker Agency Portal button
    And the user clicks the Families tab
    And the user clicks on the assigned user
    And the consumer is existing user with outstanding American Indian or Alaska Native status
    And the Broker user clicks on the Documents tab from the user's side navigation
    Then broker should see an American Indian or Alaska Native status

  Scenario: Broker representing new user with American Indian or Alaska Native status with feature disabled
    Given the ai_an_self_attestation feature is disabled
    And the Broker user logs into their account
    And the user visits home page
    And the user clicks on the Broker Agency Portal button
    And the user clicks the Families tab
    And the user clicks on the assigned user
    And the consumer is new user with attested American Indian or Alaska Native status
    And the Broker user clicks on the Documents tab from the user's side navigation
    Then broker should see an American Indian or Alaska Native status