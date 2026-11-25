package fr.nordal.itsm.security;

import fr.nordal.itsm.shared.CurrentUser;
import fr.nordal.itsm.shared.CurrentUserProvider;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Who am I: lets the frontend show the user and adapt to their roles. */
@RestController
@RequestMapping("/api/v1/me")
class MeController {

    private final CurrentUserProvider currentUserProvider;

    MeController(CurrentUserProvider currentUserProvider) {
        this.currentUserProvider = currentUserProvider;
    }

    @GetMapping
    CurrentUser me() {
        return currentUserProvider.currentUser();
    }
}
