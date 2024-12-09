@qa-done
Feature: Admin attempts to view their American Indian or Alaska Native status

  Background:
    Given bs4_consumer_flow feature is enabled
    Given Hbx Admin exists
    And Hbx Admin logs on the Hbx portal
   
  Scenario: Admin creates a New User with American Indian or Alaska Native status with feature enabled
    Given the ai_an_self_attestation feature is enabled
    When admin creates a new user with attested American Indian or Alaska Native status
    And admin navigates to the user documents page
    Then admin should see an American Indian or Alaska Native status on the documents page

  Scenario: Admin changes the American Indian or Alaska Native attestation of an existing user
    Given the ai_an_self_attestation feature is enabled
    When admin navigates to an existing user's profile who does not have American Indian or Alaska Native status
    And admin changes the American Indian or Alaska Native attestation
    And admin navigates to the documents page
    Then admin should see an American Indian or Alaska Native status on the documents page
   
  Scenario: Admin adds a dependent with American Indian or Alaska Native status during the FAA process
    Given the ai_an_self_attestation feature is enabled
    When admin navigates to an existing user's profile
    And admin starts a new financial assistance application
    And admin adds a dependent with attested American Indian or Alaska Native status
    And admin navigates to the documents page
    Then admin should see an American Indian or Alaska Native status on the dependent's documents page

  Scenario: View History is the only Admin Action available for the American Indian Status
    Given the ai_an_self_attestation feature is enabled
    When admin creates a new user with attested American Indian or Alaska Native status
    And admin navigates to the user documents page
    And admin clicks on the Actions dropdown for the American Indian Status
    Then admin should see only View History action available for the American Indian Status
   
