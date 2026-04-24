import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: const Text(
          '''SHEMET Privacy Policy

SHEMET places great emphasis on user privacy and personal information protection. When you use our products or services, we may collect and use your information. We hope that this Privacy Policy will show you how we collect, use and protect this information when you use our products or services. This Privacy Policy applies to the SHEMET platform. Before using our products or services, please read and thoroughly understand this Privacy Policy and use the products or services after confirming your understanding and agreement. If you do not agree to this Privacy Policy, you should immediately stop using our Platform Services. Once you start using our various products or services, you fully understand and agree to this Privacy Policy.

Definition You: 
"You" of this Agreement specifically refers to users who use SHEMET products or services. Personal Information: Personal information in this Agreement means any information that is recorded electronically or otherwise and may be used alone or in combination with other information to identify the identity of a particular natural person or to reflect the activities of a particular natural person. Personal information covered by this Privacy Policy includes: basic information (including personal name, date of birth, gender, address, personal telephone number, email address); personally identifiable information (including ID card, passport, etc.); personal image, sound and image; Network identification information (including system account number, IP address, email address and password protection, password and password protection answers related to the above); personal property information (transaction and consumption records and gifts and other virtual property information); address book; Internet access records (including website browsing records, software usage records, click records) personal location information (including travel information, accurate location information, accommodation information, latitude and longitude, etc.).

Privacy Policy
First, how do we collect your information
We collect and use your personal information for the following purposes described in this Privacy Policy:
The information you provided to us.

Information that you fill out or submit when you register on our platform and you use the services we provide, including your name, gender, date of birth, ID number, phone number, e-mail address, address, interests and hobbies , bank account number and related additional information (such as your area). Please note that our many services allow you to not only share information with your social network, but also openly share your relevant information with all users who use the service, for example, information that you upload or publish on our platform (including yours Public personal information, your established list), your responses to information uploaded or posted by others, and location, video, and audio information related to such information. Other users who use our services may also share information related to you (including location data, video, audio information). In particular, our social media service is designed to enable you to share information with users all over the world. You can make sharing information available in real time and widely. Therefore, please carefully consider the information content uploaded, posted, and communicated through our services. In some cases, you can control the scope of users who have the right to browse your shared information through the privacy settings of some of our services. If you want to remove your related information from our service, please contact us.

Information collected during your use of the service.

In order to better serve you, we will collect your relevant information, such information includes:
When you use our platform's services or visit the platform's webpage, we automatically receive and record your browser, computer, mobile device information, including but not limited to your IP address, browser type, language used, Date and time of visit, data on hardware and software features, and records of your web page; if you download or use our or our affiliate company's client software, or visit our mobile website to use our platform's services, we may read your location. Information related to mobile devices, including but not limited to device model, device identification code, operating system, resolution, etc. We will collect the content, information that you upload through our platform, such as the uploaded or captured text, shared photos, recordings, and the date, time, or location of such information.
  We will collect your mobile phone number, ID card, real name, and face information only when you register as a host. This information is collected to meet the requirements of relevant laws and regulations for the online real-name system (depending on the actual situation, different scenarios The real identity information collected may be different). If you do not provide such information, you may not be able to use related functions normally. The aforementioned information contains sensitive personal information. We will pop up a pop-up window to obtain your separate consent in advance and ask you to read the "Face-Corrected Personal Information Processing Authorization Agreement" in detail and click to agree. When performing face recognition, the third-party SDK will collect light sensor information to capture the external environment light conditions. In order to prevent information leakage, the anchor performs face recognition in the App and store user face data and will not share it with any third party. After face verification,when account deleted the face data will be deleted and destroyed, and we will not retain it;

How we protect and preserve your personal : information Your account is secure. Please keep your account and password information in a safe place. We will ensure that your information is not lost, misused and changed due to security measures such as backing up to other servers and encrypting user passwords. Despite the above security measures, please understand that there are no comprehensive security measures on the information network. When using our platform services for online transactions, you will inevitably disclose your personal information to your counterparty or potential counterparty, such as bank account information, contact information or postal address. Please protect your personal information and provide it to others only when necessary. If you find that your personal information has been compromised, especially if your account and password are compromised, please contact our customer service department immediately so we can take the appropriate action.

You fully understand that we may collect and use personal information without your authorization in the following circumstances:
Related to national security and public interest;
Related to criminal investigation, prosecution, trial and execution of judgments;
It is difficult to obtain personal consent to protect important legal rights such as the life and property of personal information subjects or other individuals;
The personal information collected is the subject of personal disclosure to the public;
Personal information that you collect from information disclosed by law, such as legitimate news reports, government information disclosure and other channels;
Violation of the law or violation of our platform rules allows us to take the necessary measures for you;
Required to sign a contract according to your requirements;
Maintain the conditions required for the safe and stable operation of the products or services provided, such as the discovery and disposal of products or services;
Legal news report requirements;
When an academic research institution is required to conduct statistical or academic research in the public interest and provide external academic research or to describe the results, the personal information contained in the results should be removed;
Other circumstances as stipulated by laws and regulations.

Changes to the privacy policy We may revise the terms of this Privacy Policy as appropriate and form part of this Privacy Policy. If such changes result in a significant reduction in your rights under this Privacy Policy, we will notify you by prompting or sending an email or otherwise prominently on the homepage before the amendments become effective. In this case, if you continue to use our services, you agree to be bound by this revised Privacy Policy.

Jurisdiction and application of law 

The formulation, validity, performance, interpretation and dispute resolution of this Privacy Policy apply to the laws of Germany (excluding conflict of laws). If you have any disputes or disputes with us, you should first resolve them through friendly negotiation. If you do not do so, you agree to submit the dispute to the laws of Germany Dispute.

How to contact us

If you have any questions about any terms or parts of these Terms of Service, please send your inquiries via email to officalshemet@gmail.com. Any personally identifiable information used for inquiries and responses shall be handled in accordance with these Terms of Service''',
          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        ),
      ),
    );
  }
}
