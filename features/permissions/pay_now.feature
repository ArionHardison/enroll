Feature: Hbx Admin creates a New Consumer Application for ivl users

  Background: Setup site, employer, and benefit application
    Given a CCA site exists with a benefit market

  Scenario Outline: Hbx Admin navigates into the new consumer application with paper application option and goes forward till DOCUMENT UPLOAD page
    Given a Hbx admin with <subrole> access exists
    And Hbx Admin logs on to the Hbx Portal
    And creates a consumer with SEP
    When the person enrolls in a Kaiser plan
    And I click on purchase confirm button for matched person
    Then I should click on pay now button

  Examples:
  | subrole      |
  | super admin  |