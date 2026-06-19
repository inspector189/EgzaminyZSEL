import 'package:flutter/material.dart';

class Qualification {
  final String code;
  final String description;
  final IconData icon;

  const Qualification({
    required this.code,
    required this.description,
    required this.icon,
  });
}

class Profession {
  final String name;
  final List<Qualification> qualifications;

  const Profession({
    required this.name,
    required this.qualifications,
  });
}

const List<Profession> professions = [
  Profession(
    name: 'Programista',
    qualifications: [
      Qualification(
        code: 'INF.03',
        icon: Icons.code,
        description:
            'Tworzenie i administrowanie stronami i aplikacjami internetowymi oraz bazami danych',
      ),
      Qualification(
        code: 'INF.04',
        icon: Icons.router,
        description: 'Projektowanie, programowanie i testowanie aplikacji',
      ),
    ],
  ),
  Profession(
    name: 'Informatyk',
    qualifications: [
      Qualification(
        code: 'INF.02',
        icon: Icons.memory,
        description:
            'Administracja i eksploatacja systemów komputerowych, urządzeń peryferyjnych i lokalnych sieci komputerowych',
      ),
      Qualification(
        code: 'INF.03',
        icon: Icons.code,
        description:
            'Tworzenie i administrowanie stronami i aplikacjami internetowymi oraz bazami danych',
      ),
    ],
  ),
  Profession(
    name: 'Teleinformatyk',
    qualifications: [
      Qualification(
        code: 'INF.07',
        icon: Icons.network_check,
        description:
            'Montaż i konfigurowanie lokalnych sieci komputerowych oraz administrowanie systemami operacyjnymi',
      ),
      Qualification(
        code: 'INF.08',
        icon: Icons.security,
        description:
            'Eksploatacja i konfiguracja oraz administrowanie sieciami rozległymi',
      ),
    ],
  ),
  Profession(
    name: 'Elektronik',
    qualifications: [
      Qualification(
        code: 'ELM.02',
        icon: Icons.analytics,
        description:
            'Montaż oraz instalowanie układów i urządzeń elektronicznych',
      ),
      Qualification(
        code: 'ELM.05',
        icon: Icons.build,
        description: 'Eksploatacja urządzeń elektronicznych',
      ),
    ],
  ),
  Profession(
    name: 'Elektryk',
    qualifications: [
      Qualification(
        code: 'ELE.02',
        icon: Icons.electrical_services,
        description:
            'Montaż, uruchamianie i konserwacja instalacji, maszyn i urządzeń elektrycznych',
      ),
      Qualification(
        code: 'ELE.05',
        icon: Icons.precision_manufacturing,
        description: 'Eksploatacja maszyn, urządzeń i instalacji elektrycznych',
      ),
    ],
  ),
  Profession(
    name: 'Automatyk',
    qualifications: [
      Qualification(
        code: 'ELM.01',
        icon: Icons.build_circle,
        description:
            'Montaż, uruchamianie i obsługiwanie układów automatyki przemysłowej',
      ),
      Qualification(
        code: 'ELM.04',
        icon: Icons.settings_input_component,
        description: 'Eksploatacja układów automatyki przemysłowej',
      ),
    ],
  ),
];
