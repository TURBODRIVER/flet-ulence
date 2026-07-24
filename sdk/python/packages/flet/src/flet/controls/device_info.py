from datetime import datetime
from typing import Optional

from flet.controls.base_control import value

__all__ = [
    "DeviceInfo",
    "LinuxDeviceInfo",
    "MacOsDeviceInfo",
    "WindowsDeviceInfo",
]

from flet.controls.types import Locale


@value(kw_only=True)
class DeviceInfo:
    """
    Base class for device information.

    Platform-specific classes include:
    - :class:`~flet.LinuxDeviceInfo`
    - :class:`~flet.MacOsDeviceInfo`
    - :class:`~flet.WindowsDeviceInfo`
    """

    locales: list[Locale]
    """
    The full system-reported supported locales of the device.

    This establishes the language and formatting conventions that application
    should, if possible, use to render their user interface.

    The list is ordered in order of priority, with lower-indexed locales being
    preferred over higher-indexed ones. The first element is the primary locale.

    The :attr:`flet.Page.on_locale_change` event is called
    whenever this value changes.
    """


@value(kw_only=True)
class MacOsDeviceInfo(DeviceInfo):
    """
    Device information snapshot for macOS hosts.

    Returned by :meth:`flet.Page.get_device_info` when the
    current platform is macOS. Includes CPU, memory, model, and OS version
    fields collected from native system APIs.
    """

    active_cpus: int
    """Number of active CPUs."""

    arch: str
    """Machine CPU architecture.

    Note:
        Apple Silicon Macs can return `"x86_64"` if app runs via Rosetta.
    """

    computer_name: str
    """Name given to the local machine."""

    cpu_frequency: int
    """Device CPU frequency."""

    host_name: str
    """Operating system type."""

    kernel_version: str
    """Machine kernel version.

    Examples:
        - `"Darwin Kernel Version 15.3.0: Thu Dec 10 18:40:58 PST 2015; root:xnu-3248.30.4~1/RELEASE_X86_64"`
        - `"Darwin Kernel Version 15.0.0: Wed Dec 9 22:19:38 PST 2015; root:xnu-3248.31.3~2/RELEASE_ARM64_S8000"`
    """

    major_version: int
    """The major release number, such as `10` in version 10.9.3."""

    memory_size: int
    """Machine's memory size."""

    minor_version: int
    """The minor release number, such as `9` in version 10.9.3."""

    model: str
    """Device model identifier.

    For example: `"MacBookPro18,3"`, `"Mac16,2"`.
    """

    model_name: str
    """Device model name.

    For example: `"MacBook Pro (16-inch, 2021)"`, `"iMac (24-inch, 2024)"`.
    """

    os_release: str
    """Operating system release number."""

    patch_version: int
    """The update release number, such as `3` in `version 10.9.3`."""

    system_guid: Optional[str] = None
    """Device GUID."""


@value(kw_only=True)
class LinuxDeviceInfo(DeviceInfo):
    """
    Device information for a Linux system.

    More info:
        - https://www.freedesktop.org/software/systemd/man/os-release.html
        - https://www.freedesktop.org/software/systemd/man/machine-id.html
    """

    name: str
    """A string identifying the operating system, without a version component, and \
    suitable for presentation to the user.

    Examples: `"Fedora"`, `"Debian GNU/Linux"`.

    If not set, defaults to `"Linux"`.
    """

    id: str
    """A lower-case string identifying the operating system, excluding any version \
    information and suitable for processing by scripts or usage in generated \
    filenames.

    The ID contains no spaces or other characters outside of 0–9, a–z, '.', '_' and '-'.

    Examples: `"fedora"`, `"debian"`.

    If not set, defaults to `"linux"`.
    """

    pretty_name: str
    """A pretty operating system name in a format suitable for presentation to the \
    user. May or may not contain a release code name or OS version of some kind, as \
    suitable.

    Examples: `"Fedora 17 (Beefy Miracle)"`.

    If not set, defaults to `"Linux"`.
    """

    version: Optional[str] = None
    """A string identifying the operating system version, excluding any OS name \
    information, possibly including a release code name, and suitable for presentation \
    to the user.

    Examples: `"17"`, `"17 (Beefy Miracle)"`.

    May be `None` on some systems.
    """

    id_like: Optional[list[str]] = None
    """A space-separated list of operating system identifiers in the same syntax as \
    the id value. It lists identifiers of operating systems that are closely related \
    to the local operating system in regards to packaging and programming interfaces, \
    for example listing one or more OS identifiers the local OS is a derivative from.

    Examples: an operating system with id `"centos"`, would list `"rhel"`
    and `"fedora"`, and an operating system with id `"ubuntu"` would list `"debian"`.

    May be `None` on some systems.
    """

    version_code_name: Optional[str] = None
    """A lower-case string identifying the operating system release code name, \
    excluding any OS name information or release version, and suitable for processing \
    by scripts or usage in generated filenames.

    The codename contains no spaces or other characters outside of 0–9, a–z, '.', '_'
    and '-'.

    Examples: `"buster"`, `"xenial"`.

    May be `None` on some systems.
    """

    version_id: Optional[str] = None
    """A lower-case string identifying the operating system version, excluding any OS \
    name information or release code name, and suitable for processing by scripts or \
    usage in generated filenames.

    The version is mostly numeric, and contains no spaces or other characters outside
    of 0–9, a–z, '.', '_' and '-'.

    Examples: `"17"`, `"11.04"`.

    May be `None` on some systems.
    """

    build_id: Optional[str] = None
    """A string uniquely identifying the system image used as the origin for a \
    distribution (it is not updated with system updates). The field can be identical \
    between different version_id values as build_id is only a unique identifier to a \
    specific version.

    Examples: `"2013-03-20.3"`, `"201303203"`.

    May be `None` on some systems.
    """

    variant: Optional[str] = None
    """A string identifying a specific variant or edition of the operating system \
    suitable for presentation to the user. This field may be used to inform the user \
    that the configuration of this system is subject to a specific divergent set of \
    rules or default configuration settings.

    Examples: `"Server Edition"`, `"Smart Refrigerator Edition"`.

    Note: this field is for display purposes only. The variant_id field should be used
    for making programmatic decisions.

    May be `None` on some systems.
    """

    variant_id: Optional[str] = None
    """A lower-case string identifying a specific variant or edition of the operating \
    system. This may be interpreted in order to determine a divergent default \
    configuration.

    The variant ID contains no spaces or other characters outside of
    0–9, a–z, '.', '_' and '-'.

    Examples: `"server"`, `"embedded"`.

    May be `None` on some systems.
    """

    machine_id: Optional[str] = None
    """A unique machine ID of the local system that is set during installation or \
    boot.
    The machine ID is hexadecimal, 32-character, lowercase ID. When decoded from
    hexadecimal, this corresponds to a 16-byte/128-bit value.
    """


@value(kw_only=True)
class WindowsDeviceInfo(DeviceInfo):
    """
    Device information snapshot for Windows systems.

    Returned by :meth:`flet.Page.get_device_info` on Windows.
    """

    computer_name: str
    """The computer's fully-qualified DNS name, where available."""

    number_of_cores: int
    """Number of CPU cores on the local machine."""

    system_memory: int
    """The physically installed memory in the computer, in megabytes.

    This may not be the same as available memory.
    """

    user_name: str
    """
    The name of the current user.
    """

    major_version: int
    """The major version number of the operating system.

    For example, for Windows 2000, the major version number is `5`.

    For more info, see the table in Remarks:
    https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/ns-wdm-_osversioninfoexw#remarks
    """

    minor_version: int
    """The minor version number of the operating system.

    For example, for Windows 2000, the minor version number is `0`.

    For more info, see the table in Remarks:
    https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/wdm/ns-wdm-_osversioninfoexw#remarks
    """

    build_number: int
    """The build number of the operating system.

    Examples:
        - `22000` or greater for Windows 11.
        - `10240` or greater for Windows 10.
    """

    platform_id: int
    """The operating system platform.

    For Win32 on NT-based operating systems,
    RtlGetVersion returns the value `VER_PLATFORM_WIN32_NT`.
    """

    csd_version: str
    """The service-pack version string.

    This member contains a string, such as "Service Pack 3",
    which indicates the latest service pack installed on the system.
    """

    service_pack_major: int
    """The major version number of the latest service pack installed on the system.

    For example, for Service Pack 3, the major version number is three.
    If no service pack has been installed, the value is zero.
    """

    service_pack_minor: int
    """The minor version number of the latest service pack installed on the system.

    For example, for Service Pack 3, the minor version number is zero.
    """

    suit_mask: int
    """The product suites available on the system."""

    product_type: int
    """The product type.

    This member contains additional information about the system.
    """

    reserved: int
    """Reserved for future use."""

    build_lab: str
    """Value of `HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\BuildLab` registry key.

    For example: `"22000.co_release.210604-1628"`.
    """

    build_lab_ex: str
    """Value of `HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\BuildLabEx` registry key.

    For example: `"22000.1.amd64free.co_release.210604-1628"`.
    """

    # digital_product_id: str

    display_version: str
    """Value of `HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\DisplayVersion` registry key.

    For example: `"21H2"`.
    """

    edition_id: str
    """Value of `HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\EditionID` registry key.
    """

    install_date: datetime
    """Value of `HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\InstallDate` registry key.
    """

    product_id: str
    """Displayed as "Product ID" in Windows Settings.

    Value of the `HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProductId`
    registry key.

    For example: `"00000-00000-0000-AAAAA"`.
    """

    product_name: str
    """Value of `HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProductName` registry key.

    For example: `"Windows 10 Home Single Language"`.
    """

    registered_owner: str
    """Value of the `HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\RegisteredOwner` registry key.

    For example: `"Microsoft Corporation"`.
    """

    release_id: str
    """
    Value of the `HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ReleaseId` registry key.

    For example: `"1903"`.
    """

    device_id: str
    """Displayed as "Device ID" in Windows Settings.

    Value of `HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\SQMClient\\MachineId`
    registry key.
    """
