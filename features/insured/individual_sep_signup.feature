Feature: Insured Plan Shopping on Individual market
  Background:
    Given bs4_consumer_flow feature is disable
    Given choose_shopping_method feature is disabled
    Given the FAA feature configuration is enabled
    Given individual Qualifying life events are present
    Given Individual has not signed up as an HBX user
    When Individual visits the Insured portal outside of open enrollment
    And Individual creates a new HBX account
    Then Individual should see a successful sign up message
    And Individual sees Your Information page
    When user registers as an individual
    And the individual clicks on the Continue button of the Account Setup page
    And Individual sees form to enter personal information

 Scenario: New insured user purchases on individual market thru qualifying life event
    When the individual clicks continue on the personal information page
    And the person named Patrick Doe is RIDP verified
    And Individual agrees to the privacy agreeement
    And Individual answers the questions of the Identity Verification page and clicks on submit
    Then Individual is on the Help Paying for Coverage page
    Then Individual does not apply for assistance and clicks continue
    And Individual navigates to Sep Page
    When Individual click the "Had a baby" in qle carousel
    And Individual selects a current qle date
    Then Individual should see confirmation and continue
    And Individual clicks on the continue button
    And Individual clicks on continue button on Choose Coverage page
    And Individual select three plans to compare
    Then Individual should not see any plan which premium is 0
    When Individual selects a plan on plan shopping page
    And Individual clicks on purchase button on confirmation page
    Then Individual clicks on the Continue button to go to the Individual home page
    Then Individual should land on Home page

  Scenario: New insured user selects none of the situations listed in qle carousel
    When the individual clicks continue on the personal information page
    And the person named Patrick Doe is RIDP verified
    And Individual agrees to the privacy agreeement
    And Individual answers the questions of the Identity Verification page and clicks on submit
    Then Individual is on the Help Paying for Coverage page
    Then Individual does not apply for assistance and clicks continue
    And Individual navigates to Sep Page
    When Individual clicks on None of the situations listed above apply checkbox
    And Individual clicks Back to my account button
    Then Individual should land on Home page

  Scenario: New insured user selects qle
    Given is your health coverage expanded question is disable
    When the individual clicks continue on the personal information page
    And the person named Patrick Doe is RIDP verified
    And Individual agrees to the privacy agreeement
    And Individual answers the questions of the Identity Verification page and clicks on submit
    Then Individual is on the Help Paying for Coverage page
    Then Individual does not apply for assistance and clicks continue
    And Individual navigates to Sep Page
    When Individual click the "Losing other health insurance" in qle carousel
    And Individual selects a past qle date
    Then Individual clicks no and clicks continue
    Then Individual should see successful sep message

  Scenario: New insured user purchases on individual market thru lose of coverage QLE with expanded question
    Given is your health coverage expanded question is enabled
    When Individual clicks on continue
    And the person named Patrick Doe is RIDP verified
    And Individual agrees to the privacy agreeement
    And Individual answers the questions of the Identity Verification page and clicks on submit
    Then Individual is on the Help Paying for Coverage page
    Then Individual does not apply for assistance and clicks continue
    And Individual navigates to Sep Page
    When Individual click the "Losing other health insurance" in qle carousel
    And Individual selects a past qle date
    Then Individual clicks yes and clicks continue
    Then Individual should see successful sep message
