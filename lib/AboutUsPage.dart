import 'dart:ui';
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    this.returnToHome = false,
  });

  final bool returnToHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary.withOpacity(0.25);

    final authors = [
      {
        "name": "Marta Błaszczyk",
        "class": "Klasa 5TG",
        "desc":
            "Nazywam się Marta Błaszczyk i jestem uczennicą klasy 5TG. W projekcie egzaminy.zsel.edu.pl pełniłam rolę liderki zespołu — koordynowałam pracę grupy, przydzielałam zadania oraz organizowałam spotkania, podczas których planowaliśmy kolejne etapy działań. Testowałam również nowe funkcjonalności pojawiające się na stronie.\n\n"
            "Stworzyłam fundament całej aplikacji, w tym kompletny system testów (jedno pytanie, testy z 40 losowymi pytaniami oraz bazę wszystkich pytań). Opracowałam także moduł logowania użytkowników, odpowiadałam za przygotowanie podglądów egzaminów, a także stworzyłam zaawansowany moduł testów dla nauczycieli, który umożliwia samodzielne tworzenie sprawdzianów — zarówno przez wybór konkretnych pytań, jak i ich losowanie — tak, aby każdy uczeń otrzymał identyczny zestaw.\n"
            "Zajmowałam się również statystykami użytkowników oraz mechanizmami zapisywania i analizowania trudności pytań.\n\n"
            "Na co dzień tworzę własne gry w Unity oraz Unreal Engine, programując głównie w C# i C++. Uwielbiam rozwijać się w dziedzinie programowania i tworzyć nowe projekty. Prywatnie jestem opiekunką uroczego psa o imieniu Leoś, który wiernie towarzyszy mi przy nauce i podczas programowania — najczęściej siedząc na kolanach."
      },
      {
        "name": "Patryk Pietrzyk",
        "class": "Klasa 5TG",
        "desc":
            "Nazywam się Patryk Pietrzyk i jestem uczniem klasy 5TG.\n"
            "Na stronie egzaminy.zsel.edu.pl odpowiadałem za przygotowanie wstępnego środowiska testowego, a także zajmuję się backendem całego projektu. To ja pozyskiwałem pytania dla wszystkich kwalifikacji oraz stworzyłem kluczowe zabezpieczenia, takie jak obsługa sesji i ciastek. W pełni samodzielnie zaprojektowałem i wykonałem również edytor pytań w panelu administratora.\n\n"
            "Na co dzień programuję w C#, a w wolnym czasie stale dokształcam swoje umiejętności programistyczne, poszerzając wiedzę i eksperymentując z nowymi technologiami.\n"
            "Prywatnie jestem opiekunem psa o imieniu Nero."
      },
      {
        "name": "Krzysztof Konieczny",
        "class": "Klasa 5TG",
        "desc":
            "Nazywam się Krzysztof Konieczny i jestem uczniem klasy 5TG. W projekcie egzaminy.zsel.edu.pl odpowiadałem za polepszanie praktyk kodu oraz wygląd aplikacji. Moje zadania obejmowały optymalizację, poprawność, redukcję zbędnych powtórzeń oraz zastępowanie przestarzałego kodu, a także prezentację aplikacji i jej responsywność, co usprawniło tempo oraz wygodę pracy oraz wpłynęło na satysfakcję korzystania z aplikacji.\n\n"
            "W wolnym czasie interesuje się głównie informatyką oraz programowaniem. Lubię pływać, moim ulubionym stylem jest styl motylkowy(delfin/koń). Posiadam psa o rasie Border Collie, który wabi się Bandi. Bardzo lubi przeszkadzać i psocić się, gdy chce zwrócić na siebie uwagę."
      },
      {
        "name": "Radek Biesiada",
        "class": "Klasa 5TG",
        "desc":
            "Nazywam się Radek Biesiada i jestem uczniem klasy 5TG. W projekcie egzaminy.zsel.edu.pl odpowiadałem za kluczowe elementy związane z funkcjonalnością systemu. Moje zadania obejmowały tworzenie raportów, generowanie plików PDF, a także wdrożenie modułu Administratorów Nadrzędnych, który znacząco usprawnił zarządzanie platformą oraz podniósł poziom bezpieczeństwa i kontroli nad danymi użytkowników.\n\n"
            "Poza realizacją zadań projektowych interesuję się szeroko pojętą technologią. W wolnym czasie gram na komputerze, majsterkuję, a także rozwijam swoje umiejętności w zakresie programowania. Prywatnie jestem właścicielem psa o imieniu Alex, który towarzyszy mi na co dzień i dodaje energii do pracy oraz nauki."
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("O nas"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (returnToHome) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              const Text(
                "FAQ",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              ExpansionTile(
                title: const Text(
                  "1. Skąd wziął się pomysł na stworzenie aplikacji EgzaminyZawodoweZSEL i dlaczego taki system był potrzebny?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Wcześniej w naszej szkole nie istniała żadna aplikacja, która kompleksowo wspierałaby przygotowania do egzaminów zawodowych. "
                      "Pomysł narodził się z potrzeby ułatwienia pracy zarówno uczniom, jak i nauczycielom. Chcieliśmy stworzyć jedną, spójną platformę, "
                      "dzięki której uczniowie mogliby wygodnie rozwiązywać testy i na bieżąco analizować swoje wyniki, a nauczyciele — tworzyć własne zestawy pytań, "
                      "śledzić postępy uczniów oraz identyfikować te zagadnienia, które sprawiają największe trudności i omawiać je później na lekcjach.\n\n"
                      "Do tej pory każda kwalifikacja korzystała z innych zewnętrznych stron z testami, a uczniowie musieli wysyłać zrzuty ekranu z wynikami na serwer. "
                      "Było to niewygodne, a dodatkowo nie zawsze rzetelnie odzwierciedlało ich realną wiedzę — chociażby ze względu na łatwość ściągania. "
                      "Nasza aplikacja miała to zmienić: stworzyć bezpieczne, przejrzyste i jednolite środowisko do nauki oraz wesprzeć nauczycieli w monitorowaniu pracy uczniów.",
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 12),

              ExpansionTile(
                title: const Text(
                  "2. Jakie technologie zostały wykorzystane do stworzenia aplikacji?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Front-end aplikacji został w całości napisany w Dartcie, natomiast część back-endowa opiera się na PHP oraz bazie danych zarządzanej poprzez phpMyAdmin. "
                      "Wszystkie kluczowe pliki, jak i sama baza danych, znajdują się na serwerze szkolnym, na którym hostowana jest również domena projektu.\n\n"
                      "Darta wybraliśmy dlatego, że umożliwia nam tworzenie aplikacji na wiele platform jednocześnie — nie tylko jako strony internetowej, ale również aplikacji desktopowych i mobilnych. "
                      "Posiada też bogaty ekosystem bibliotek, co znacznie usprawniło i przyspieszyło naszą pracę.",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ExpansionTile(
                title: const Text(
                  "3. Co było najtrudniejsze w tworzeniu aplikacji?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Największym wyzwaniem okazał się brak czasu. Oprócz szkoły każdy z nas miał również obowiązki prywatne, dlatego bywało trudno dopinać wszystko na czas, szczególnie gdy komuś coś wypadło lub nie mógł dokończyć zadania.\n\n"
                      "Wyzwanie stanowił też sam język — nikt z nas wcześniej nie pracował w Dartcie. Zdecydowaliśmy się jednak spróbować i dziś wiemy, że była to świetna decyzja, bo zdobyliśmy cenne doświadczenie i nauczyliśmy się pracy z nową technologią.\n\n"
                      "Dodatkową trudnością było przygotowanie części back-endowej oraz zebranie całej bazy pytań. W każdej kwalifikacji jest ich naprawdę dużo, a zależało nam, aby nasza baza była jak najbogatsza i różnorodna. "
                      "Był to bardzo czasochłonny etap, ale kluczowy dla działania aplikacji.",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ExpansionTile(
                title: const Text(
                  "4. Co daje Wam największą satysfakcję z pracy nad projektem?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Najwięcej satysfakcji daje nam widok realnych efektów — świadomość, że zarówno uczniowie, jak i nauczyciele już aktywnie korzystają z naszej aplikacji. "
                      "Cieszymy się, że mogliśmy w praktyczny sposób wesprzeć proces przygotowań do egzaminów zawodowych.\n\n"
                      "Włożyliśmy w projekt mnóstwo pracy, czasu i zaangażowania, dlatego każde miłe słowo ze strony użytkowników, każda pozytywna opinia czy informacja zwrotna naprawdę nas podnosi na duchu "
                      "i motywuje do dalszego rozwijania funkcjonalności aplikacji.",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              const Text(
                "O autorach aplikacji",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 40),

              ...authors.map((a) => _buildAuthorCard(a, color)).toList(),
            ],
          ),
        ),
      );
  }

  Widget _buildAuthorCard(Map<String, String> author, Color blurColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: blurColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${author["name"]} — ${author["class"]}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(height: 1.5, color: Colors.white30),

                    const SizedBox(height: 12),

                    Text(
                      author["desc"]!,
                      style: const TextStyle(fontSize: 16, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
