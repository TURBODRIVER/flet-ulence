from enum import Enum
from typing import Annotated

from flet.controls.base_control import control
from flet.controls.control import Control
from flet.utils.validation import V

__all__ = ["AutofillGroup", "AutofillGroupDisposeAction", "AutofillHint"]


class AutofillHint(str, Enum):
    """
    Predefined autofill hint identifiers for text fields.

    Each enum value represents semantic input meaning (for example city,
    email, or password) and is translated to platform-specific autofill
    constants when available. On unsupported platforms, the raw hint string
    value is used as-is.
    """

    ADDRESS_CITY = "addressCity"
    """
    The input field expects an address locality (city/town).

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    ADDRESS_CITY_AND_STATE = "addressCityAndState"
    """
    The input field expects a city name combined with a state name.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    ADDRESS_STATE = "addressState"
    """
    The input field expects a region/state.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    BIRTHDAY = "birthday"
    """
    The input field expects a person's full birth date.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    BIRTHDAY_DAY = "birthdayDay"
    """
    The input field expects a person's birth day(of the month).

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    BIRTHDAY_MONTH = "birthdayMonth"
    """
    The input field expects a person's birth month.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    BIRTHDAY_YEAR = "birthdayYear"
    """
    The input field expects a person's birth year.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    COUNTRY_CODE = "countryCode"
    """
    The input field expects an [ISO 3166-1-alpha-2](https://www.iso.org/standard/63545.html) country code.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    COUNTRY_NAME = "countryName"
    """
    The input field expects a country name.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_EXPIRATION_DATE = "creditCardExpirationDate"
    """
    The input field expects a credit card expiration date.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_EXPIRATION_DAY = "creditCardExpirationDay"
    """
    The input field expects a credit card expiration day.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_EXPIRATION_MONTH = "creditCardExpirationMonth"
    """
    The input field expects a credit card expiration month.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_EXPIRATION_YEAR = "creditCardExpirationYear"
    """
    The input field expects a credit card expiration year.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_FAMILY_NAME = "creditCardFamilyName"
    """
    The input field expects the holder's last/family name as given on a credit card.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_GIVEN_NAME = "creditCardGivenName"
    """
    The input field expects the holder's first/given name as given on a credit card.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_MIDDLE_NAME = "creditCardMiddleName"
    """
    The input field expects the holder's middle name as given on a credit
    card.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_NAME = "creditCardName"
    """
    The input field expects the holder's full name as given on a credit card.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_NUMBER = "creditCardNumber"
    """
    The input field expects a credit card number.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_SECURITY_CODE = "creditCardSecurityCode"
    """
    The input field expects a credit card security code.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    CREDIT_CARD_TYPE = "creditCardType"
    """
    The input field expects the type of a credit card, for example "Visa".

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    EMAIL = "email"
    """
    The input field expects an email address.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    FAMILY_NAME = "familyName"
    """
    The input field expects a person's last/family name.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    FULL_STREET_ADDRESS = "fullStreetAddress"
    """
    The input field expects a street address that fully identifies a location.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    GENDER = "gender"
    """
    The input field expects a gender.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    GIVEN_NAME = "givenName"
    """
    The input field expects a person's first/given name.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    IMPP = "impp"
    """
    The input field expects a URL representing an instant messaging protocol
    endpoint.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    JOB_TITLE = "jobTitle"
    """
    The input field expects a job title.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    LANGUAGE = "language"
    """
    The input field expects the preferred language of the user.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    LOCATION = "location"
    """
    The input field expects a location, such as a point of interest, an \
    address,or another way to identify a location.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    MIDDLE_INITIAL = "middleInitial"
    """
    The input field expects a person's middle initial.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    MIDDLE_NAME = "middleName"
    """
    The input field expects a person's middle name.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    NAME = "name"
    """
    The input field expects a person's full name.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    NAME_PREFIX = "namePrefix"
    """
    The input field expects a person's name prefix or title, such as "Dr.".

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    NAME_SUFFIX = "nameSuffix"
    """
    The input field expects a person's name suffix, such as "Jr.".

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    NEW_PASSWORD = "newPassword"
    """
    The input field expects a newly created password for save/update.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    NEW_USERNAME = "newUsername"
    """
    The input field expects a newly created username for save/update.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    NICKNAME = "nickname"
    """
    The input field expects a nickname.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    ONE_TIME_CODE = "oneTimeCode"
    """
    The input field expects a SMS one-time code.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    ORGANIZATION_NAME = "organizationName"
    """
    The input field expects an organization name corresponding to the person, \
    address, or contact information in the other fields associated with this \
    field.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    PASSWORD = "password"
    """
    The input field expects a password.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    PHOTO = "photo"
    """
    The input field expects a photograph, icon, or other image corresponding \
    to the company, person, address, or contact information in the other \
    fields associated with this field.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    POSTAL_ADDRESS = "postalAddress"
    """
    The input field expects a postal address.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    POSTAL_ADDRESS_EXTENDED = "postalAddressExtended"
    """
    The input field expects an auxiliary address details.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    POSTAL_ADDRESS_EXTENDED_POSTAL_CODE = "postalAddressExtendedPostalCode"
    """
    The input field expects an extended ZIP/POSTAL code.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    POSTAL_CODE = "postalCode"
    """
    The input field expects a postal code.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    STREET_ADDRESS_LEVEL1 = "streetAddressLevel1"
    """
    The first administrative level in the address.

    This is typically the province in which the address is located.
    In the United States, this would be the state. In Switzerland, the canton.
    In the United Kingdom, the post town.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    STREET_ADDRESS_LEVEL2 = "streetAddressLevel2"
    """
    The second administrative level, in addresses with at least two of them.
    In countries with two administrative levels, this would typically be the
    city, town, village, or other locality in which the address is located.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    STREET_ADDRESS_LEVEL3 = "streetAddressLevel3"
    """
    The third administrative level, in addresses with at least three \
    administrative levels.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    STREET_ADDRESS_LEVEL4 = "streetAddressLevel4"
    """
    The finest-grained administrative level, in addresses which have four levels.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    STREET_ADDRESS_LINE1 = "streetAddressLine1"
    """
    The input field expects the first line of a street address.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    STREET_ADDRESS_LINE2 = "streetAddressLine2"
    """
    The input field expects the second line of a street address.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    STREET_ADDRESS_LINE3 = "streetAddressLine3"
    """
    The input field expects the third line of a street address.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    SUB_LOCALITY = "subLocality"
    """
    The input field expects a sublocality.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TELEPHONE_NUMBER = "telephoneNumber"
    """
    The input field expects a telephone number.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TELEPHONE_NUMBER_AREA_CODE = "telephoneNumberAreaCode"
    """
    The input field expects a phone number's area code, with a \
    country-internal prefix applied if applicable.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TELEPHONE_NUMBER_COUNTRY_CODE = "telephoneNumberCountryCode"
    """
    The input field expects a phone number's country code.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TELEPHONE_NUMBER_DEVICE = "telephoneNumberDevice"
    """
    The input field expects the current device's phone number, usually for \
    Sign Up / OTP flows.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TELEPHONE_NUMBER_EXTENSION = "telephoneNumberExtension"
    """
    The input field expects a phone number's internal extension code.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TELEPHONE_NUMBER_LOCAL = "telephoneNumberLocal"
    """
    The input field expects a phone number without the country code and area \
    code components.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TELEPHONE_NUMBER_LOCAL_PREFIX = "telephoneNumberLocalPrefix"
    """
    The input field expects the first part of the component of the telephone \
    number that follows the area code, when that component is split into two \
    components.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TELEPHONE_NUMBER_LOCAL_SUFFIX = "telephoneNumberLocalSuffix"
    """
    The input field expects the second part of the component of the telephone
    number that follows the area code, when that component is split into two
    components.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TELEPHONE_NUMBER_NATIONAL = "telephoneNumberNational"
    """
    The input field expects a phone number without country code.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TRANSACTION_AMOUNT = "transactionAmount"
    """
    The amount that the user would like for the transaction \
    (e.g. when entering a bid or sale price).

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    TRANSACTION_CURRENCY = "transactionCurrency"
    """
    The currency that the user would prefer the transaction to use, in \
    [ISO 4217 currency code](https://www.iso.org/iso-4217-currency-codes.html).

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    URL = "url"
    """
    The input field expects a URL.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """

    USERNAME = "username"
    """
    The input field expects a username or an account name.

    This hint will be translated to the below values on different platforms:

    The hint string will be used as-is.
    """


class AutofillGroupDisposeAction(str, Enum):
    """
    Predefined autofill context clean-up actions.
    """

    COMMIT = "commit"
    """
    Destroys the current autofill context after informing the platform to save
    the user input from it.
    """

    CANCEL = "cancel"
    """
    Destroys the current autofill context without saving the user input.
    """


@control("AutofillGroup")
class AutofillGroup(Control):
    """
    Used to group autofill controls together.
    """

    content: Annotated[
        Control,
        V.visible_control(),
    ]
    """
    The content of this group.

    Raises:
        ValueError: If it is not visible.
    """

    dispose_action: AutofillGroupDisposeAction | str = AutofillGroupDisposeAction.COMMIT
    """
    The action to be run when this group is the topmost and it's being disposed, in \
    order to clean up the current autofill context.
    """
