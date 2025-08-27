# Security Policy

## Reporting Security Vulnerabilities

Dynamic Devices takes security seriously. If you discover a security vulnerability in the meta-dynamicdevices-bsp layer, please report it responsibly.

### How to Report

**Please DO NOT create public GitHub issues for security vulnerabilities.**

Instead, please report security issues via one of the following methods:

#### Email (Preferred)
- **Security Email**: security@dynamicdevices.co.uk
- **Subject**: `[SECURITY] meta-dynamicdevices-bsp: Brief description`

#### Alternative Contact
- **General Contact**: info@dynamicdevices.co.uk
- **Technical Lead**: ajlennon@dynamicdevices.co.uk

### What to Include

When reporting a security vulnerability, please include:

1. **Description** of the vulnerability
2. **Steps to reproduce** the issue
3. **Potential impact** assessment
4. **Affected versions** or commits
5. **Suggested fix** (if available)
6. **Your contact information** for follow-up

### Response Timeline

- **Acknowledgment**: Within 48 hours of receipt
- **Initial Assessment**: Within 5 business days
- **Status Updates**: Weekly until resolution
- **Fix Timeline**: Varies by severity (Critical: 7 days, High: 14 days, Medium: 30 days)

### Severity Levels

- **Critical**: Remote code execution, privilege escalation
- **High**: Local privilege escalation, information disclosure
- **Medium**: Denial of service, minor information leaks
- **Low**: Configuration issues, non-exploitable bugs

### Security Best Practices

This BSP layer follows security best practices:

- **Secure Boot**: HAB (High Assurance Boot) support for i.MX platforms
- **Verified Boot**: U-Boot signature verification
- **Encrypted Storage**: LUKS support for sensitive data
- **Regular Updates**: Security patches applied promptly
- **Minimal Attack Surface**: Only necessary services enabled

### Supported Versions

Security updates are provided for:

- **Current Release**: Latest tagged version
- **LTS Releases**: Long-term support versions
- **Active Branches**: Main development branch

### Coordinated Disclosure

We follow responsible disclosure practices:

1. **Private Reporting**: Initial report kept confidential
2. **Investigation**: Security team investigates and develops fix
3. **Patch Development**: Fix created and tested
4. **Coordinated Release**: Public disclosure after fix is available
5. **CVE Assignment**: Request CVE if applicable

### Security Resources

- **Yocto Project Security**: https://wiki.yoctoproject.org/wiki/Security
- **NXP Security**: https://www.nxp.com/support/security:SECURITY
- **Linux Kernel Security**: https://www.kernel.org/category/security.html

### Contact Information

**Dynamic Devices Ltd**
- Website: https://dynamicdevices.co.uk
- Security Email: security@dynamicdevices.co.uk
- Business Hours: Monday-Friday, 9:00-17:00 GMT

---

*This security policy is effective as of 2024 and may be updated periodically.*
